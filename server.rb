#!/usr/bin/env ruby -w
require 'socket'
require_relative 'helper.rb'
require_relative 'colorize.rb' # from the 'colorize' gem

###############################################################################
# the Server class
###############################################################################
class Server
  include Logger

  # the admin tag - what will be displayed when the Admin sends a message
  ADMIN_NAME = 'ODIN'
  ADMIN_TAG = "[#{ADMIN_NAME}]".colorize(color: :light_white,
                                         background: :blue) + ': '

  #############################################################################
  # Constructor - opens the TCP socket for the server, initilizes some key vals
  #############################################################################
  def initialize(port)
    @server = TCPServer.new(port)

    @connections = {}
    @rooms   =     {}  # will contain: { room_name: [ client_names] }
    @clients =     {}  # will contain: { client_name: client_fd }
    @connections[:server]  = @server
    @connections[:rooms]   = @rooms
    @connections[:clients] = @clients

    # initialize some default rooms
    @rooms[:midgard]  = [] # -> the default room. new clients join this one.
    @rooms[:asgard]   = []
    @rooms[:niflheim] = []

    # the admin may join a room to participate in it
    @current_room = nil # will hold the room symbol

    # close all sockets upon ^C
    trap('INT') { @clients.each { |name, fd | fd.close }; @server.close; exit }

    run
  end

  #############################################################################
  # spawn new threads as news clients connect, each thread will handle that
  # user's inputs
  #############################################################################
  def run
    # allow the admin to run and execute commands
    Thread.new { handle_admin_input }

    loop do # kernel#loop -> repeatedly executes the block
      # listen for new clients to connect and make one thread per client
      Thread.start(@server.accept) do | client |
        # once the client connets, get that client's user name
        nick_name = client.gets.chomp.to_sym
        # check that the username is unique
        if nick_name.empty? || nick_name.to_s == ADMIN_NAME
          client.puts 'Invalid username!'
          client.close
          log('Killing thread. Invalid username.', :debug)
          Thread.kill self
        else
          @connections[:clients].each do |other_name, other_client|
            if nick_name == other_name || client == other_client
              # TODO: handle this little problem!!
              client.puts 'This username already exist'
              client.close
              log('Killing thread. Duplicate username.', :debug)
              Thread.kill self
            end
          end
        end
        # display who just connected
        log("\"#{nick_name}\" connected - #{client}", :info)
        # add this client to the list of connections
        @connections[:clients][nick_name] = client
        # add this client to the midgard room
        change_room(:midgard, nick_name)
        # listen for incoming messages and commands from the client
        listen_user_messages(nick_name, client)
      end
    end.join
  end

  # ///////////////////////////////////////////////////////////////////////// #
  # ///////////////////////////  SERVER HANDLING   ////////////////////////// #
  # ///////////////////////////////////////////////////////////////////////// #

  #############################################################################
  # this method allows the Server Admin to execute commands and change / modify
  # some of the rooms / users
  #############################################################################
  def handle_admin_input
    display_options
    loop do
      print '>'
      input = $stdin.gets.chomp # get the admin's input
      log("admin's input: #{input}", :debug)
      case input.downcase.split.first
      when 't'       then display_stats
      when 'rooms'   then display_rooms
      when 'clients' then display_clients
      when 'all'     then display_all
      when 'kick'    then kick(input.split[1..-1].join(' ').to_sym) # kick(usr)
      when 'sendall' then send_all(input.split[1..-1].join(' '))    # send(msg)
      when 'send'
        input = input.split
        # send_room(room, message)
        send_room(input[1].to_sym, input[2..-1].join(' '))
      when 'p'
        input = input.split
        # send_client(client_name, message)
        send_client(input[1].to_sym, input[2..-1].join(' '), false, true)
      when 'join'    then room_join(input.split[1..-1].join(' ')) # join(room)
      when 'leave'   then room_leave
      when '?'       then display_options
      else
        if @current_room
          send_room(@current_room, input)
        else
          puts 'invalid entry!'
        end
      end
    end
  end

  #############################################################################
  # displays to the admin some statistics - number of clients, rooms, etc...
  #############################################################################
  def display_stats
    puts "Number of clients: #{@clients.size}"
    puts "Number of rooms: #{@rooms.size}"
    room = @rooms.max_by { |name, clients| clients.size }
    puts "Most used room: #{room.first}, #{room.last.size} client(s)"
    puts "Server Admin listening to room: #{@current_room}" if @current_room
  end

  #############################################################################
  # displays the names of each room, and the number of clients in them
  #############################################################################
  def display_rooms
    puts 'Rooms:'
    @rooms.each do |name, clients|
      puts "\t#{name}, #{clients.size} client(s)"
    end
  end

  #############################################################################
  # displays the names of all the clients, and the room names tehy belong to.
  #############################################################################
  def display_clients
    puts 'Clients: (NAME, ROOM)'
    @rooms.each do |room_name, client_names|
      client_names.each do |client_name|
        puts "\t#{client_name}, #{room_name}"
      end
    end
  end

  #############################################################################
  # display statistics, room names, client names
  #############################################################################
  def display_all
    display_stats
    display_rooms
    display_clients
  end

  #############################################################################
  # kicks a client out of the server
  #############################################################################
  def kick(client_name)
    unless @clients.key?(client_name)
      puts "invalid client_name. Usage: kick <client_name>"
      return
    end

    log("\"#{client_name}\" kicked from the server", :info)

    # find out which room this client used to belong
    old_room =  @connections[:rooms].find do |room_name, clients|
      clients.include?(client_name)
    end

    # let the client know he got kicked and then close the connections
    msg = "#{ADMIN_NAME} has kicked you out of the halls of chatting!"
    @connections[:clients][client_name].puts msg
    @connections[:clients][client_name].close

    # delete the client from the list of clients in the old room
    old_room.last.delete(client_name)

    # delete the client from the list of clients
    @connections[:clients].delete(client_name)

    # let the users of the room know that the user disconnected
    msg = "\"#{client_name}\" has disconnected from #{old_room.first}!"
    send_room(old_room.first, msg, nil, true)

    # NOTE: no need to kill the thread for that client. Ruby handles it
    # automatically.
  end

  #############################################################################
  # sends a message to all the clients
  #############################################################################
  def send_all(message)
    # loop, sending the message to each room
    @connections[:rooms].each { |name, clients| send_room(name, message) }
  end

  #############################################################################
  # sends a message to a single room
  #############################################################################
  def send_room(room, message, client_name = nil, message_is_room_info = false)
    # check if the inputs were given
    unless room && message
      puts 'usage: send <room> <message>'
      return
    end

    # check that the room exists
    unless @connections[:rooms].key?(room)
      puts 'invalid room'
      return
    end

    # prepend the name of the client if it was given
    if client_name
      # TODO: implement a color scheme for displaying client_names?!
      message.prepend("#{client_name}: ")
    elsif message_is_room_info
      message = message.colorize(color: :white, background: :magenta)
    else
      message.prepend(ADMIN_TAG) unless message.start_with?(ADMIN_TAG)
    end

    # send the message to each client in the room (except for the given name)
    @connections[:rooms][room].each do |client_nam3|
      if client_nam3 != client_name
        @connections[:clients][client_nam3].puts message
      end
    end

    # if the message was sent from a client, and the admin "is" in this room,
    # then display it to the server admin
    if @current_room == room && (client_name || message_is_room_info)
      puts message
    end
  end

  #############################################################################
  # sends a messate to a single client.
  # if from_client_name is given, then it's a private message from one person
  # to another.
  # Note: as it is right now, a person can send a private message to self...
  #############################################################################
  def send_client(client_name, message,
                  from_client_name = false, from_admin = false)
    # if it's from another client, then prepend the [private] tag
    if from_client_name
      message.prepend("[private - #{from_client_name}]: ")
    elsif from_admin
      message.prepend(ADMIN_TAG)
    end

    # if the destination is valid, then send it
    if @clients.key?(client_name)
      @connections[:clients][client_name].puts message
    # else if is a private message, then check if it's adressed to the admin
    elsif from_client_name
      if client_name.to_s == ADMIN_NAME
        puts message
      else
        @clients[from_client_name].puts "the user [#{client_name}] doesn't " +
                                                                     'exist'
      end
    # else then let the server admin know about the error
    else
      log("the user [#{client_name}] doesn't exist", :info)
    end
  end

  #############################################################################
  # after the @current_room is set, sendroom will display to the admin messages
  # from that room
  #############################################################################
  def room_join(room_name)
    @current_room = room_name.to_sym
  end

  #############################################################################
  # makes the server admin stop listening conversations from the previously
  # joined room
  #############################################################################
  def room_leave
    @current_room = nil
  end

  #############################################################################
  # disconnects a client - closes the socket, updates the connections and the
  # room.
  #############################################################################
  def disconnect(client_name)
    log("\"#{client_name}\" disconnected", :info)

    # find out which room this client used to belong
    old_room =  @connections[:rooms].find do |room_name, clients|
      clients.include?(client_name)
    end

    # close the client's socket
    @connections[:clients][client_name].close

    # delete the client from the list of clients in the old room
    old_room.last.delete(client_name)

    # delete the client from the list of clients
    @connections[:clients].delete(client_name)

    # let the users of the room know that the user disconnected
    msg = "\"#{client_name}\" has disconnected from #{old_room.first}!"
    send_room(old_room.first, msg, nil, true)

    # we're done w/ the thread for this client!
    log('Killing thread. User disconnected.', :debug)
    Thread.kill self
  end

  #############################################################################
  # displays the options to the Server admin.
  #############################################################################
  def display_options
    puts "commands:\n"
    puts "\t" + 't       - display stats'
    puts "\t" + 'rooms   - display the list of rooms'
    puts "\t" + 'clients - display the list of clients'
    puts "\t" + 'all     - display all stats, rooms and clients'
    puts "\t" + 'kick    - kick a client'
    puts "\t" + 'sendall - send a message to all rooms'
    puts "\t" + 'send    - send a message to a single room'
    puts "\t" + 'p       - send a private message to a client'
    puts "\t" + 'join    - joins a room'
    puts "\t" + 'leave   - leaves the current room'
  end


  # ///////////////////////////////////////////////////////////////////////// #
  # ///////////////////////////  CLIENT HANDLING   ////////////////////////// #
  # ///////////////////////////////////////////////////////////////////////// #

  #############################################################################
  # constantly listen to new messages from the client and then act according
  # to thise nessages. If the message is not a command, then display the
  # message to that client's room. Else, then act according to the command that
  # was given.
  #############################################################################
  def listen_user_messages(client_name, client_fd)
    loop do
      # get the client's input
      message = client_fd.gets.chomp
      msg = message.split

      if command?(msg[0])
        case msg[0]
        when '%p'
          # NOTE: right now, this only works for usernames of 1 word
          send_client(msg[1].to_sym, msg[2..-1].join(' '), client_name)
        when '%c' then change_room(msg[1..-1].join(' ').to_sym, client_name)
        when '%r' then list_rooms(client_name)
        when '%a' then list_all_users(client_name)
        when '%u' then list_room_users(client_name)
        when '%t' then list_all(client_name)
        when '%q' then disconnect(client_name)
        else
          log("failed to parse the user's command!", :error)
        end
      elsif msg[0] != "\0" # allow the client to send null characters to
                           # test if the socket is opened
        # then send the message to the whole room
        room = @connections[:rooms].find do |name, clients|
          clients.include?(client_name)
        end

        unless room
          log("BAD ERROR!!! couldn't find the room for the user!", :fatal)
        end

        send_room(room.first, message, client_name)
      end
    end
  end

  #############################################################################
  # assigns the client to the new_room
  #############################################################################
  def change_room(new_room, client_name)
    old_room =
      @rooms.find { |room_name, clients| clients.include?(client_name) }
    old_room ||= []

    if old_room.first != new_room
      old_room = old_room.first
      @connections[:rooms][old_room].delete(client_name) if old_room
      @connections[:rooms][new_room] ||= []
      @connections[:rooms][new_room] << client_name

      # update the old room
      msg = "\"#{client_name}\" has left #{old_room}!"
      send_room(old_room, msg, nil, true) if old_room

      # update the client
      msg = "Joining #{new_room}...\n"
      msg << "Welcome to " +
        new_room.to_s.colorize(color: :black, background: :light_green) +
        "!\t\t #{@rooms[new_room].size} users in this room!"
      send_client(client_name, msg)

      # broadcast the message to the room
      msg = "\"#{client_name}\" has joined #{new_room}!"
      send_room(new_room, msg, nil, true)
    end
  end

  #############################################################################
  # send a list of all rooms to the client
  #############################################################################
  def list_rooms(client_name)
    msg = "List of Rooms:\n\t"
    msg << @rooms.keys.join(', ')
    send_client(client_name, msg)
  end

  #############################################################################
  # send a list of all the users to the client
  #############################################################################
  def list_all_users(client_name)
    msg = "List of Users:\n\t"
    msg << @clients.keys.join(', ')
    send_client(client_name, msg)
  end

  #############################################################################
  # send a list of all the room users to the client
  #############################################################################
  def list_room_users(client_name)
    room = @rooms.find { |room_name, clients| clients.include?(client_name) }
    msg = "List of Users in #{room.first}:\n\t"
    msg << room.last.join(', ')
    send_client(client_name, msg)
  end

  #############################################################################
  # sends the list of rooms and of all users to the client
  #############################################################################
  def list_all(client_name)
    list_rooms(client_name)
    list_all_users(client_name)
  end

  #############################################################################
  # checks if the user's input was a command
  #############################################################################
  def command?(input)
    input == '%p' || input == '%c' || input == '%r' ||
      input == '%u' || input == '%a' || input == '%q' || input == '%t'
  end
end

###############################################################################
# get's the PORT from ARGV and starts the server w/ it
###############################################################################
port = ARGV.first ? ARGV.first : 6789 # port number optionally set with ARGV
Server.new(port)

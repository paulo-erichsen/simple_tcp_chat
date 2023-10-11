#!/usr/bin/env ruby -w
# -*- coding: utf-8 -*-
require "socket"
require_relative 'colorize'

###############################################################################
# the Client Class
###############################################################################
class Client

  #############################################################################
  # constructor - displays the initial screen, prompts for user name and
  # starts a thread for listening messages and a thread for sending messages
  #############################################################################
  def initialize(server)
    @server = server
    init
    @request = nil
    @response = nil
    send_username
    listen
    send
    @request.join
    @response.join
  end

  #############################################################################
  # listens for messages from the server and displays them
  #############################################################################
  def listen
    @response = Thread.new do
      loop do
        msg = @server.gets.chomp
        puts "#{msg}"
      end
    end
  end

  #############################################################################
  # gets inputs from the client and sends them to the server
  #############################################################################
  def send
    display_options
    @request = Thread.new do
      loop do
        # get the user's input
        msg = $stdin.gets.chomp

        # if it's a %?, then display the options
        if msg == '%?'
          display_options
          next
        end

        # send the user's message to the server
        begin
          @server.puts(msg)
          exit if msg.start_with?('%q')
        rescue Exception => e
          puts e.message
          exit
        end
      end
    end
  end

  #############################################################################
  # prompt for the username and send it to the server
  #############################################################################
  def send_username
    print "Enter your " + 'Viking'.colorize(:red) + ' username: '
    msg = $stdin.gets.chomp.split.first
    @server.puts(msg)
  end

  #############################################################################
  # display the available options
  #############################################################################
  def display_options
    puts "commands:\n"
    puts "\t" + '%r - display the list of rooms'
    puts "\t" + '%a - display a list of all users'
    puts "\t" + '%u - display the list of users in this room'
    puts "\t" + '%t - display the list of rooms and of all users'
    puts "\t" + '%p - send a private message: %p <username> <message>'
    puts "\t" + '%c - change rooms %c <room_name>'
    puts "\t" + '%q - quit'
  end

  #############################################################################
  # init - clears the window, resize's it and then displays a Viking boat
  #############################################################################
  def init
    system 'clear'
    print "\e[8;50;80;t" # resize window the window - height: 50, width: 80

    print "
 ██▒   █▓ ██▓ ██ ▄█▀ ██▓ ███▄    █   ▄████     ▄████▄   ██░ ██  ▄▄▄     ▄▄▄████
▓██░   █▒▓██▒ ██▄█▒ ▓██▒ ██ ▀█   █  ██▒ ▀█▒   ▒██▀ ▀█  ▓██░ ██▒▒████▄   ▓  ██▒
 ▓██  █▒░▒██▒▓███▄░ ▒██▒▓██  ▀█ ██▒▒██░▄▄▄░   ▒▓█    ▄ ▒██▀▀██░▒██  ▀█▄ ▒ ▓██░
  ▒██ █░░░██░▓██ █▄ ░██░▓██▒  ▐▌██▒░▓█  ██▓   ▒▓▓▄ ▄██▒░▓█ ░██ ░██▄▄▄▄██░ ▓██▓
   ▒▀█░  ░██░▒██▒ █▄░██░▒██░   ▓██░░▒▓███▀▒   ▒ ▓███▀ ░░▓█▒░██▓ ▓█   ▓██▒ ▒██▒░
   ░ ▐░  ░▓  ▒ ▒▒ ▓▒░▓  ░ ▒░   ▒ ▒  ░▒   ▒    ░ ░▒ ▒  ░ ▒ ░░▒░▒ ▒▒   ▓▒█░ ▒ ░░
   ░ ░░   ▒ ░░ ░▒ ▒░ ▒ ░░ ░░   ░ ▒░  ░   ░      ░  ▒    ▒ ░▒░ ░  ▒   ▒▒ ░   ░
     ░░   ▒ ░░ ░░ ░  ▒ ░   ░   ░ ░ ░ ░   ░    ░         ░  ░░ ░  ░   ▒    ░
      ░   ░  ░  ░    ░           ░       ░    ░ ░       ░  ░  ░      ░  ░

                                                 ::
                                .'`\"\"::..       ::
                              :     ,  `\"\"::..  ::
                            :   ,   |\\ ,__  `\"\"::..
                          :     |\\   \\/   `.     `\"\"::..
                         :      \\ `-.:.     `\\        `\"\"::..
                        :        `-.__ `\\=====|           `\"\"::..
                       :            /=`'/   ^_\\                .'
                      :           .'   /\\   .=)              .'
                      :        .-'  .'|  '-(/_|            .'
     :.              :       .'  __(  \\  .'`             .'
     ::              :      /_.'`  `.  |`              .'
     |:             :                \\ |              :
     ||             :       ____     |/              :
     |:.            :   ..\"\"    \"\"-.                :
     ||:.           : .'            `.             :
     || `:.          :                `.          :
   __||  `\"\"::..     :                 :.         :
.-\"  :|       `\"\"::..`:                ::.       :
     ::            `\"\"::..            ::  .      :
     `:.                `\"\"::..       ::   :     :           __
      `:.                    `\"\"::.. ::_____:____:__    _.--'
   ___.-`::..                  _.-\"\"\"\"\"             \"\"\"\"----....
      `--._`\"::.          _.-'
               `\"\":: ___.-'                       -dd-
            ____--\"\"\"

                                                            VERSION 1.0





"

    puts "Welcome to the chat of the norsemen!"
  end
end

###############################################################################
# get the HOSTNAME and PORT from the command line
###############################################################################
if ARGV.size != 2
  puts 'Usage: ruby client.rb HOSTNAME PORT'
  exit(1)
end

# connect to the server, creating the socket
server = TCPSocket.open(ARGV[0], ARGV[1])

# catch ^C
trap('INT') do
  begin
    server.puts '%q'
  rescue Exception => e
  end
  puts ''
  exit
end

# initializes the client object and runs it
Client.new(server)

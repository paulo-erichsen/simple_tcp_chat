This is a simple chat program I wrote in Ruby that uses TCP sockets. Clients are able to connect to the server and chat with people in the same room.

How to run:

    # server:
    ruby server.rb PORT_NUMBER

    # client:
    ruby client.rb HOSTNAME PORT_NUMBER # hostname of server's machine

Example:

    ruby server.rb 6789 # once started, let it just listen for connections

    ruby client.rb 127.0.0.1 6789 # localhost if running the client on the same machine

Server Admin Options:

       t       - display stats
       rooms   - display the list of rooms
       clients - display the list of clients
       all     - display all stats, rooms and clients
       kick    - kick a client
       sendall - send a message to all rooms
       send    - send a message to a single room
       p       - send a private message to a client
       join    - joins a room
       leave   - leaves the current room

Client Options:

       %r - display the list of rooms
       %a - display a list of all users
       %u - display the list of users in this room
       %t - display the list of rooms and of all users
       %p - send a private message: %p <username> <message>
       %c - change rooms %c <room_name>
       %q - quit

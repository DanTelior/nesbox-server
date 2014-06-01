package com.nesbox;

import js.Node;

/**
 * ...
 * @author Vadim Grigoruk
 */

private class Player
{
	public static var Empty:UInt = 0xffffffff;
	public static var Mask:UInt = 0xfff;
	
	public var socket:NodeNetSocket;
	public var input:UInt;
	
	public function new() 
	{
		input = Empty;
	}
}

private class Room
{
	public var uid:String;
	public var frameskip:Int;
	public var first:Player;
	public var second:Player;
	
	public function new() 
	{
		frameskip = 0;
		first = new Player();
		second = new Player();
	}
}
 
class Server
{
	var port:Int = 8080;
	var rooms:Map<NodeNetSocket, Room >;
	
	public function new() 
	{
		if (Node.process.argv.length <= 2)
		{
			Node.console.info('Please, specify port number!');
			Node.console.info('Example: node server.js <port>\n');
		}
		else
		{
			port = Std.parseInt(Node.process.argv[2]);
		}
		
		Node.console.log('Starting Nesbox server on '+port+' port');
		
		rooms = new Map();
		
		Node.net.createServer(listener).listen(port);
	}
	
	function listener(socket:NodeNetSocket)
	{
		socket.setNoDelay(true);
		
		socket.on(NodeC.EVENT_STREAM_DATA, function(data:NodeBuffer)
		{
			if (rooms.exists(socket))
			{
				var room = rooms.get(socket);
				var input = data.readUInt32BE(0);
				
				room.first.socket == socket 
					? room.first.input = input 
					: room.second.input = input;
				
				if (room.first.input != Player.Empty 
					&& room.second.input != Player.Empty)
				{
					var input = (room.first.input & Player.Mask) | ((room.second.input & Player.Mask) << 12);
					
					data.writeUInt32BE(input, 0);
					
					room.first.socket.write(data, NodeC.BINARY);
					room.second.socket.write(data, NodeC.BINARY);
					
					room.first.input = Player.Empty;
					room.second.input = Player.Empty;
				}
			}
			else
			{
				var json = data.toString(NodeC.UTF8);
				
				if (json.indexOf('<policy-file-request/>') == 0)
				{
					var policy = '<?xml version="1.0"?><cross-domain-policy><allow-access-from domain="nesbox.com" to-ports="'+port+'" /><allow-access-from domain="*.nesbox.com" to-ports="'+port+'" /></cross-domain-policy>';
					var buffer = new NodeBuffer(policy.length + 2);
					buffer.write(policy, 0);
					buffer.writeInt16BE(0, policy.length);
					
					socket.write(buffer, NodeC.BINARY);
					
					return;
				}
				
				var message = Node.parse(json);
				
				switch(message.type)
				{
				case 'handshake':
					doHandshake(socket, message.room, message.frameskip);
				}
			}
		});
		
		socket.on(NodeC.EVENT_STREAM_CLOSE, function()
		{
			var room = rooms.get(socket);
			
			if (room != null)
			{
				rooms.remove(socket);
				
				if (room.first.socket != null)
				{
					room.first.socket.destroy();
					room.first.socket = null;
					
					Node.console.log('<- first player has disconnected from the room ' + room.uid);
				}
				
				if (room.second.socket != null)
				{
					room.second.socket.destroy();
					room.second.socket = null;
					
					Node.console.log('<- second player has disconnected from the room ' + room.uid);
				}

			}
		});
	}
	
	function doHandshake(socket:NodeNetSocket, roomUid:String, frameskip:Int)
	{
		if (roomUid == null)
		{
			roomUid = uid();
			
			var room = new Room();
			room.uid = roomUid;
			room.first.socket = socket;
			room.frameskip = frameskip;
			rooms.set(socket, room);
			
			Node.console.log('-> first player has connected to the room ' + room.uid);
		}
		else
		{
			var roomFound = false;
			
			for (room in rooms)
			{
				if (room.uid == roomUid)
				{
					if (room.second.socket != null)
					{
						socket.destroy();
						return;
					}
					
					room.second.socket = socket;
					frameskip = room.frameskip;
					rooms.set(socket, room);
					
					Node.console.log('-> second player has connected to the room ' + room.uid);
					
					roomFound = true;
					break;
				}
			}
			
			if (!roomFound)
			{
				socket.destroy();
				return;
			}
		}
		
		socket.write(Node.stringify( { type:'handshake', room:roomUid, frameskip:frameskip } ), NodeC.UTF8);
	}
	
	static function uid():String
	{
		return Std.string(Std.random(Std.int(Date.now().getTime())));
	}
	
}
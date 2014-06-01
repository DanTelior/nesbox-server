package com.nesbox;
import js.Node;

/**
 * ...
 * @author Vadim Grigoruk
 */

class Main 
{
	
	static function main() 
	{
		Node.process.on(NodeC.EVENT_PROCESS_UNCAUGHTEXCEPTION, onUncaughtException);
		
		var server = new Server();
	}
	
	static function onUncaughtException(error:NodeErr)
	{
		Node.console.error('Uncaught exception:', error);
	}

}
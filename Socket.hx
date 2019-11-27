import js.node.Buffer;
import js.node.net.Socket;
import js.node.net.Server;
import js.node.Net;

private class SocketInput extends haxe.io.BytesInput {

    public function new(b:haxe.io.Bytes) {
        super(b);
        this.bigEndian = true;
    }
    public var available(get, never) : Int;

    function get_available() {
        return length-position;
    }
}


private class SocketOutput extends haxe.io.Output {
    var s : js.node.net.Socket;

    public function new(s) {
        this.s = s;
    }
    
    public function wait() {
        s.cork();
    }
    
    override public function flush() {
        s.uncork();
    }

    override function writeByte( c : Int ) {
        var bf = Buffer.alloc(1);
        bf.fill(c);
        s.write(bf);
    }

    override function write( b : haxe.io.Bytes )  {
        var bf = Buffer.hxFromBytes(b);
        s.write(bf);        
    }
    
    override function writeBytes( b : haxe.io.Bytes, pos : Int, len : Int ) : Int {
        if( len > 0 ) {
            var bf = Buffer.hxFromBytes(b);
            s.write(bf);
        }
        return len;
    }

    override function writeInt32( i : Int ) {
        var bf = Buffer.alloc(4);
        bf.writeInt32BE(i,0);
        s.write(bf);
    }

    override function writeString( str : String,  ?encoding:haxe.io.Encoding) {
        var bf = Buffer.from(str);
        s.write(bf);
    }

}

class Socket {

    static var openedSocks = [];
    var client : Bool;
    var s : js.node.net.Socket;
    var serv : Server;
    
    public var out(default, null) : SocketOutput;
    public var input(default, null) : SocketInput;
    public var timeout(default, set) : Null<Float>;

    public function new() {
        client = true;
    }

    public function set_timeout(t:Null<Float>) {
        if( s != null ) s.setTimeout(t == null ? 0x7FFFFFFF : Math.ceil(t * 1000));
        return this.timeout = t;
    }

    public function connect( host : String, port : Int, onConnect : Void -> Void ) {
        s = new js.node.net.Socket();
        s.connect({host:host,port:port}, function() {
            out = new SocketOutput(s);
            bindEvents();
            onConnect();
        });
    }

    function bindEvents() {
        s.on(SocketEvent.Error, function(e:js.lib.Error) {
            onError(e.message);
        });
        s.on(SocketEvent.Data, function(data:Buffer) {
            input = new SocketInput(data.hxToBytes());          
            onData();
        });
        s.on(SocketEvent.End, function() {
            close();
            onError("Closed");
        });
    }
    
    public static inline var ALLOW_BIND = true;

    public function bind( host : String, port : Int, onConnect : Socket -> Void, listenCount = 5 ) {
        client = false;
        close();
        openedSocks.push(this);
        serv = Net.createServer(function(sock) {
            var s = new Socket();
            s.s = sock;
            s.bindEvents();
            s.out = new SocketOutput(sock);
            openedSocks.push(s);
            onConnect(s);
        });
        try serv.listen(port, host) catch( e : Dynamic ) {
            close();
            throw e;
        };
        serv.maxConnections = listenCount;
    }

    public function close() {
        openedSocks.remove(this);
        if (client) {
            if( s != null ) {
                try s.end() catch( e : Dynamic ) { };
                s = null;
            }   
        } else {
            if( serv != null ) {
                try serv.close() catch( e : Dynamic ) { };
                serv = null;
            }           
        }
    }

    public dynamic function onError(msg:String) {
        throw "Socket Error " + msg;
    }

    public dynamic function onData() {
    }

}
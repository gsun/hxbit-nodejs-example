
class Cursor implements hxbit.NetworkSerializable {

    @:s var color : Int;
    @:s public var uid : Int;
    @:s public var x(default, set) : Float;
    @:s public var y(default, set) : Float;

    var net : Test;

    public function new( color, uid=0 ) {
        this.color = color;
        this.uid = uid;
        init();
        x = 0;
        y = 0;
    }

    public function networkGetOwner() {
        return this;
    }

    function set_x( v : Float ) {
        if( v == x ) return v;
        return this.x = v;
    }

    function set_y( v : Float ) {
        return this.y = v;
    }

    public function toString() {
        return "Cursor " + StringTools.hex(color, 6)+(enableReplication?":ALIVE":"");
    }

    function init() {
        net = Test.inst;
        

        enableReplication = true;
        
        net.log("Init "+this);

    }

    @:rpc function blink( s : Float ) {
    }

    public function alive() {
        init();
        // refresh bmp
        this.x = x;
        this.y = y;
        if( uid == net.uid ) {
            net.cursor = this;
            net.host.self.ownerObject = this;
        }
        
        net.log("alive "+this);
    }
    
    public function networkAllow(mode:hxbit.NetworkSerializable.Operation, prop:Int, client:hxbit.NetworkSerializable) {
        return true;
    }

}

//PARAM=-lib hxbit
class Test {

    static var HOST = "127.0.0.1";
    static var PORT = 6676;

    public var host : SocketHost;
    //public var event : hxd.WaitEvent;
    public var uid : Int;
    public var cursor : Cursor;

    public function init() {
        //event = new hxd.WaitEvent();
        host = new SocketHost();
        host.setLogger(function(msg) log(msg));

        #if server
        host.wait(HOST, PORT, function(c) {
            log("Client Connected");
        });
        host.onMessage = function(c,uid:Int) {
            log("Client identified ("+uid+")");
            var cursorClient = new Cursor(0x0000FF, uid);
            c.ownerObject = cursorClient;
            c.sync();
        };
        log("Server Started");

        start();

        #else
        // we could not start the server
        log("Connecting");

        uid = 1 + Std.random(1000);
        host.connect(HOST, PORT, function(b) {
            if( !b ) {
                log("Failed to connect to server");
                return;
            }
            log("Connected to server");
            host.sendMessage(uid);
        });         
        #end    

        
    }

    public function log( s : String, ?pos : haxe.PosInfos ) {
        pos.fileName = (host.isAuth ? "[S]" : "[C]") + " " + pos.fileName;
        haxe.Log.trace(s, pos);
    }

    function start() {
        cursor = new Cursor(0xFF0000);
        log("Live");
        host.makeAlive();
    }

    public static var inst : Test;
    static function main() {
        inst = new Test();
        inst.init();
    }
    
    public function new() {}

}
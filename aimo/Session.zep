namespace Aimo;

class Session {
    public function init(array! config)
    {
        
    }

    public function start()
    {
        session_start();
    }

    public function set(string! name,data)
    {
        let _SESSION[name]=data;
    }

    public function get(string! name)
    {
        return isset _SESSION[name] ? _SESSION[name] : null;
    }

    public function clear()
    {
        let _SESSION = [];
    }

    public function destroy()
    {
        let _SESSION = [];
        session_destroy();
    }
}
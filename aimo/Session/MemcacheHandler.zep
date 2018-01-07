namespace Aimo\Session;

class MemcacheHandler implements SessionHandlerInterface
{
    public function open(string path , string name )->boolean
    {
        return true;
    }
    public function read(string! id)->string
    {
        return "";
    }
    public function write(string! id ,string! data )->boolean
    {
        return true;
    }

    public function destroy(string! id)->boolean 
    {
        return true;
    }

    public function gc(integer ttl) -> boolean
    {
        return true;
    }

    public function close() -> boolean 
    {
        return true;
    }
}
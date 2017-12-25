namespace Aimo\Cache;
class Memcache implements CacheInterface {
    private memcache;
    
    public function __construct(<CacheInterface> memcache) {
        let this->memcache = memcache;
    }
    
    public function load(string key) {
        var ret;
        let ret = this->memcache->get("orm.".key);
        if ret === false {
            return null;
        }
        return ret;
    }
    
    public function save(string key, data) {
        this->memcache->set("orm.".key, data);
    }
}
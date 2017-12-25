namespace Aimo\Cache;
/** Cache using file
*/
class File implements CacheInterface {
    private filename;
    private data = [];
    
    public function __construct(string filename) {
        let this->filename = filename;
        let this->data = unserialize(file_get_contents(filename));
    }
    
    public function load(string key) {
        if !isset(this->data[key]) {
            return null;
        }
        return this->data[key];
    }
    
    public function save(string key, data) {
        if !isset(this->data[key]) || this->data[key] !== data {
            let this->data[key] = data;
            return file_put_contents(this->filename, serialize(this->data), LOCK_EX);
        }
    }
    
}
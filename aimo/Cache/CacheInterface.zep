namespace Aimo\Cache;
interface CacheInterface {
    
    /** Load stored data
    * @param string
    * @return mixed or null if not found
    */
    public function load(string key);
    
    /** Save data
    * @param string
    * @param mixed
    * @return null
    */
    public function save(string key, data);
    
}
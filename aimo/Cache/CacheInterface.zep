namespace Aimo\Cache;
/**
 * Aimo\Cache\CacheInterface
 *
 * interface for cache 
 */
interface CacheInterface {
    /** 
     * Check if Cache ready
     *
     * @return boolean
     */
    public function isConnected();
    /** 
     * write data to cache
     *
     * @param string
     * @param mixed
     * @return void
     */
    public function set(string! key, data, ttl = null);

    /** 
     * read data from cache
     *
     * @param string
     * @return mixed
     */
    public function get(string! key);

    /** 
     * remove data from cache
     *
     * @param string
     * @param mixed
     * @return null
     */
    public function delete(string! key);

    /** 
     * clear all data
     *
     * @param string
     * @param mixed
     * @return null
     */
    public function clear();
    
}
namespace Aimo\Cache;
use Aimo\Cache;
/**
 * Cache implements
 *
 * @author  Eric,<wangyinglei@yeah.net> Aimosoft.cn
 */
class File extends Cache implements CacheInterface {
    
    protected connected = false;
    protected prefix = "Aimo_";
    protected options = [];
    
    /**
     * Constructor
     *
     * 缓存类构造函数
     *
     * <code>
     * $fileCache = new File([
     *     'cache_path' => './runtime/',
     *     'cache_ttl' => 1800,         //默认缓存时间
     *     'cache_path_level' => 3,     //缓存目录深度
     *     'cache_subdir' => true,      //启用子目录
     *     'cache_check' => false,      //是否开启数据校检，开启后影响性能，默认关闭
     *     'cache_compress' => false,   //是否开启数据压缩，开启后影响性能，默认关闭
     * ]);
     * </code>
     */
    public function __construct(array options = [])->void
    {
        var stat,dir_perms;//,file_perms;
        if isset options["cache_path"] {
            let this->options["cache_path"] = rtrim(options["cache_path"],"\\/")."/";
        } else {
            throw "File cache path required";
        }
        let this->options["cache_ttl"] = isset options["cache_ttl"] ? (int) options["cache_ttl"] : 1800;
        let this->options["cache_path_level"] = isset options["cache_ttl"] ? (int) options["cache_path_level"] : 3;
        let this->options["cache_compress"] = isset options["cache_compress"] ? !!options["cache_compress"] : false;
        let this->options["cache_check"] = isset options["cache_check"] ? !!options["cache_check"] : false;
        let this->options["cache_subdir"] = isset options["cache_subdir"] ? !!options["cache_subdir"] : true;
        let stat = stat( this->options["cache_path"] );
        let dir_perms = stat["mode"] & 0007777; // Get the permission bits.
        //let file_perms = dir_perms & 0000666; // Remove execute bits for files.
        if !is_dir( this->options["cache_path"] ) {
            if !mkdir( this->options["cache_path"]){
                throw "File Cache dir is not writeable";
            }
            chmod( this->options["cache_path"], dir_perms );
        }
        let this->connected = is_dir( this->options["cache_path"] ) && is_writeable ( this->options["cache_path"] );
    }
    
    /**
     * 是否已连接
     * @return boolean
     */
    public function isConnected()->boolean
    {
        return this->connected;
    }
    
    /**
     * 取缓存存储文件
     * @param unknown_type name
     * @return string
     */
    private function filename(string! name)->string
    {
        let name = md5( name );
        string dir = "",filename="";
        if this->options["cache_subdir"] {
            int i;
            int e = this->options["cache_path_level"] - 1;
            // 使用子目录
            if this->options["cache_path_level"] {
                for i in range(0,e){
                    let dir .= substr(name,i,1)."/";
                }
            }
            if !is_dir( this->options["cache_path"] . dir ) {
                mkdir( this->options["cache_path"] . dir, 0777, true );
            }

            let filename = dir . this->prefix . name . ".php";

        } else {

            let filename = this->prefix.name.".php";
        }
        return this->options["cache_path"] . filename;
    }
    
    /**
     * 读取缓存
     * @param unknown_type name
     * @return boolean|mixed
     */
    public function get(string! name)
    {
        string cachename;
        var content,check,filename;
        int expire;
        let cachename = "cache_".name;
        let filename = this->filename( name );
        if !is_file( filename ) {
            return false;
        }
        
        let content = file_get_contents( filename );
        
        if false !== content {
            let expire = ( int ) substr( content, 8, 12 );
            if (expire != - 1) && (time() > filemtime( filename ) + expire) {
                //缓存过期删除缓存文件
                unlink( filename );
                return false;
            }
            if this->options["cache_check"] { //开启数据校验
                let check   = substr( content, 20, 32 );
                let content = substr( content, 52, - 3 );
                if check != md5( content ) { //校验错误
                    return false;
                }
            } else {
                let content = substr( content, 20, - 3 );
            }
            if this->options["cache_compress"] && function_exists( "gzcompress" ) {
                //启用数据压缩
                let content = gzuncompress( content );
            }
            let content = unserialize( content );
            return content;
        } else {
            return false;
        }
    }
    
    /**
     * 写缓存
     * @param str name
     * @param str|array value
     * @param int expire
     * @return boolean
     */
    public function set(string! name, value, expire = null)->boolean
    {
        var data,check,filename;
        if null === expire {
            let expire = this->options["cache_ttl"];
        }
        
        let filename = this->filename(name);
        let data = serialize( value );
        if this->options["cache_compress"] && function_exists( "gzcompress" ) {
            let data = gzcompress(data, 3 );//数据压缩
        }

        //开启数据校验
        let check = this->options["cache_check"] ? md5( data ) : "";
        let data = "<?php\n//" . sprintf( "%012d", expire ) . check . data . "\n?>";
        if file_put_contents( filename, data ) {
            clearstatcache();
            return true;
        } else {
            return false;
        }
    }
    
    /**
     * 删除缓存
     *
     * 删除文件缓存
     * @param str name
     * @return boolean
     */
    public function delete(string! name)->boolean
    {
        return unlink(this->filename(name));
    }
    

    /**
     * 删除所有当前配置中制定目录下缓存
     *
     * 删除所有当前配置中制定目录下缓存
     * @param str name
     * @return boolean
     */
    public function clear()->boolean
    {
        var path,dir,file,check;
        let path = this->options["cache_path"];
        let dir  = opendir( path );
        if dir {
            loop  {
                let file = readdir( dir );
                if !file {
                    break;
                }
                let check = is_dir( file );
                if !check {
                    unlink( path . file );
                }
            }
            closedir( dir );
            return true;
        }
        return false;
    }
}
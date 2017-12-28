namespace Aimo;
/**
 * Class loader
 *
 * @package Aimo
 * @author Eric,<fonqing@gmail.com>
 *
 */
class Loader
{
    /* 路径映射 */
    private static vendorMap = [];

    /**
     * 添加命名空间映射
     *
     * <code>
     * Aimo\Loader::addNamespace('PHPExcel', APP_PATH.'vendor/phpoffice/src/phpexcel');
     * </code>
     *
     * @param array nspaces
     */
    public static function addNamespace(string! nspace,string! dir)->void
    {
        let self::vendorMap[nspace] = dir;
    }

    /**
     * 批量添加命名空间映射
     *
     * <code>
     * Aimo\Loader::addNamespaces([
     *    'PHPExcel' => APP_PATH.'vendor/phpoffice/src/phpexcel',
     *    'GuzzleHttp' => APP_PATH.'vendor/GuzzleHttp/src',
     * ]);
     * </code>
     *
     * @param array nspaces
     */
    public static function addNamespaces(array! nspaces)->void
    {
        var nspace,dir;
        for nspace,dir in nspaces {
            let self::vendorMap[nspace] = dir;
        }
    }

    /**
     * 自动加载器
     *
     * <code>
     * use Aimo\Loader;
     * spl_autoload_register("Loader::autoload");
     * </code>
     */
    public static function autoload(string! klass)->void
    {
        var file;
        let file = self::findFile(klass);
        if file_exists(file) {
            self::includeFile(file);
        }
    }

    /**
     * 解析文件路径
     *
     * 根据命名空间查找类文件
     *
     * @param string klass
     * @return string
     */
    private static function findFile(string! klass)->string
    {
        var vendor,vendorDir,filePath;
        let vendor = substr(klass, 0, strpos(klass, "\\")); // 顶级命名空间
        let vendorDir = self::vendorMap[vendor]; // 文件基目录
        let filePath = substr(klass, strlen(vendor)) . ".php"; // 文件相对路径
        return strtr(vendorDir . filePath, "\\", DIRECTORY_SEPARATOR); // 文件标准路径
    }

    /**
     * 载入php文件
     *
     * 载入PHP文件
     *
     * @param string file
     */
    private static function includeFile(string! file)->void
    {
        if is_file(file) {
            require file;
        }
    }
}
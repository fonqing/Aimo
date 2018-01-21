namespace Aimo;
class File extends \SplFileObject {

    public function __construct(string! file)
    {
        parent::__construct(file);
    }

    /**
     * Get file size
     *
     * <code>
     * $file = new Aimo\File("test.doc");
     * dump($file->formatSize());
     * </code>
     */
    public function formatSize(int! precision = 2) -> string
    {
        var size;
        let size   = this->getSize();
        array unit = ["B","KB","MB","GB","TB","PB"];
        int x = 0,c;
        let c = (int) count(unit);
        while size >= 1024 && x < c {
            let size = size/1024;
            let x    = x + 1;
        }
        return round(size, precision) . "" . unit[x];
    }
}
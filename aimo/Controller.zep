namespace Aimo;

class Controller {
	public static function success(string msg,string url,int wait = 3)->void
    {

    }

    public static function notFound()
    {

    }

    public static function error(string msg,string url)
    {

    }

    public static function json(array data)->void
    {
        header("Content-type:application/json;charset=utf-8");
        die(json_encode(data));
    }

    public function render(string mca, array data = [])
    {
        View::render(mca, data);
    }
}
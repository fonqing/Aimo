namespace Aimo;

class Controller {
    public function __construct()
    {
        //Event::trigger('Controller_init');
        View::init(Config::get("view"));
        //Event::trigger('View_init');
    }
    public function success(string msg,string url,int wait = 3)->void
    {

    }

    public static function notFound()
    {
        header("HTTP/1.1 404 Not Found");
        header("Status: 404 Not Found");
        exit();
    }

    public function error(string msg,string url)
    {

    }

    public function json(array data)->void
    {
        header("Content-type:application/json;charset=utf-8");
        die(json_encode(data));
    }

    public function render(string mca, array data = [])
    {
        View::render(mca, data);
    }
}

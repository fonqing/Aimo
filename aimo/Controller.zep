namespace Aimo;

class Controller {
    public function __construct()
    {
        Event::trigger("controller_init");
        View::init(Config::get("view"));
        Event::trigger("view_init");
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

    public function render(string! mca="", array! data = [])
    {
        Event::trigger("before_render", [mca, data]);
        View::render(mca, data);
        Event::trigger("after_render", [mca, data]);
    }
}

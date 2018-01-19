namespace Aimo;

class Controller {

    public function __construct()
    {
        Event::trigger("controller_init");
        View::init(Config::get("view"));
        Event::trigger("view_init");
    }

    /**
     * Show success page in Controller
     *
     *<code>
     * $this->success('Operation success!','/admin/login.php');
     *</code>
     */
    public function success(string msg,string url,int wait = 3)->void
    {
        //TODO: implement
    }


    /**
     * Cause HTTP 404 Controller
     *
     *<code>
     * self::notFound();
     *</code>
     */
    public static function notFound()
    {
        header("HTTP/1.1 404 Not Found");
        header("Status: 404 Not Found");
        exit();
    }

    /**
     * Show Error page in Controller
     *
     *<code>
     * $this->error('Operation failed!','/error_detail.php');
     *</code>
     */
    public function error(string msg,string url)
    {
        //TODO: implement
    }

    /**
     * Response JSON data in controller
     *
     *<code>
     * $this->json(['status'=>1,'msg'=>'infomation']);
     *</code>
     */
    public function json(array data)->void
    {
        header("Content-type:application/json;charset=utf-8");
        die(json_encode(data));
    }

    /**
     * Response JSON data in controller
     *
     *<code>
     * $this->ajaxReturn(['status'=>1,'msg'=>'infomation']);
     *</code>
     */
    public function ajaxReturn(array data) 
    {
        this->json(data);
    }


    /**
     * Assign variables to View
     *
     *<code>
     * $this->assign('name','value');
     *</code>
     */
    public function assign(string! name,var data)
    {
        View::assign(name, data);
    }


    /**
     * Show page files
     *
     *<code>
     * $this->render();
     * //or
     * $this->render('news/view');
     * //or
     * $this->render('news/view',[
     *     'title' => 'title',
     *     'content' => 'content',
     * ]);
     *</code>
     */
    public function render(string! mca="", array! data = [])
    {
        Event::trigger("before_render", [mca, data]);
        View::render(mca, data);
        Event::trigger("after_render", [mca, data]);
    }
}

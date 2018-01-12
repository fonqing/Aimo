namespace Aimo;

/**
 * Simple Event Manager
 */
class Event
{
    /**
     * @var array
     */
    protected static _events = [];

    /**
     * 批量注册事件
     *
     * <code>
     * user Aimo\Event;
     * Event::register([
     *    'app_init'  => 'namespace\\Handler::onAppInit',
     *    'view_init' => 'namespace\\Handler::onViewInit',
     * ]);
     * </code>
     *
     * @param array 事件数组
     */
    public static function register(array! events)
    {
        var eName,func;
        for eName,func in events {
            if !empty func {
                self::on(eName, func);
            }
        }
    }

    /**
     * 注册事件
     *
     * <code>
     * user Aimo\Event;
     * Event::on('application_start', function(){
     *     var_dump(func_get_args());
     * });
     * </code>
     *
     * @param string eventName 事件名称
     * @param callable|Closure func
     */
    public static function on(string! eventName,func)->void
    {
        if !empty eventName && !empty func {
            let self::_events[eventName]=func;
        }
    }

    /**
     * 触发事件
     *
     * <code>
     * user Aimo\Event;
     * Event::trigger('application_start');
     * </code>
     *
     * @param string eventName 事件名称
     * @param array args
     * @return mixed
     */
    public static function trigger(string! eventName,array! args=[])
    {
        var handler;
        if fetch handler, self::_events[eventName] {
            if is_callable(handler) {
                return call_user_func_array(handler, args);
            }
        }
        return "$AIMO$";
    }
}

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
        if is_callable(func) || func instanceof \Closure {
            let self::_events[eventName]=func;
        }
        throw "Event :".eventName." body must be callable or instanceof Closure";
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
    public static function trigger(string! eventName,array args = [])
    {
        if isset self::_events[eventName] {
            return call_user_func_array(self::_events[eventName], args);
        }
        return "$AIMO$";
    }
}
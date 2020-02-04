namespace Aimo;
/**
 * Class Validator
 *
 * @package Aimo
 * @author  Eric wong,<fonqing@gmail.com>
 * @copyright Aimosoft Studio 2020
 *
 * @example
 * <code>
 * $rules = [
 *     "username" => ["required","minLength"=>8],
 *     "password" => ["required"],
 *     "gender"   => ["in"=>["Male","Female"]],
 *     "height"   => ["between"=>[100,300]],
 *     "idcard"   => ["required","callback" => function($value){
 *          return preg_match('/^[0-9][a-z]{16}$/i', $value);
 *      }]
 * ];
 * $validator = new Aimo\Validator();
 * $validator->setData($_POST);
 * #validator->setRules($rules);
 * $validator->setMessages([
 *     "username.required"  => "Username is required",
 *     "username.minLength" => "Username at least 8 characters",
 *     "password.required"  => "Password is required",
 * ]);
 * var_dump($validator->isValid());
 * </code>
 */
class Validator
{
    /**
     * @var array rule message
     */
    private messages = [];

    /**
     * @var array Error messages
     */
    private errors = [];

    /**
     * @var array rules
     */
    private rules = [];

    /**
     * @var array data
     */
    private data = [];

    /**
     * Validator constructor.
     *
     * @param array $rules
     * @param array $messages
     */
    public function __construct(array! rules = [],array! messages = [])
    {
        if !empty(rules) {
            let this->rules = rules;
        }
        if !empty(messages) {
            let this->data = messages;
        }
    }

    /**
     * Add callback validate rules
     *
     * @param mixed $value
     * @param mixed $func
     * @param string $message
     * @return bool
     * @throws \Exception
     */ 
     public function callback(val,func,string message="")
     {
         var result;
         if is_callable(func) {
             let result = call_user_func(func, val);
              if !result {
                  return false;
              }
              return true;
         }
         throw "Callback validator invalid";
     }

    /**
     * Data
     *
     * @param array $data
     */
    public function setData(array! data)->void
    {
        let this->data = data;
    }

    /**
     * Rules
     *
     * @param array $rules
     */
    public function setRules(array! rules)->void
    {
        let this->rules = rules;
    }

    /**
     * Error messages
     *
     * @param array $messages
     */
    public function setMessages(array! $messages)->void
    {
        let this->messages = messages;
    }

    /**
     * @return array
     */
    public function getErrors()->array
    {
        return (array) this->errors;
    }

    /**
     * Validate a rule with value
     *
     * @param mixed $value
     * @param string $rule
     * @param string $message
     * @return bool
     * @throws \Exception
     */
    public function validate(value, rule, message = "")->bool
    {
        if method_exists(this, rule) {
            if !call_user_func([this,rule], value) {
                let this->errors[]=message;
                return false;
            }
            return false;
        }
        throw "Validate rule dose't exists";
    }

    /**
     * Validate a filed
     *
     * @param string $field
     * @param mixed $data
     * @param array $rules
     * @return bool
     */
    private function validOne(field, data, array rules)->bool
    {
        var key,value,msgKey;
        array maps = [
            "bool":"_bool",
            "int":"_int",
            "integer":"_integer",
            "float":"_float",
            "array":"_array",
            "in":"_in"
        ];
        for key,value in rules {
            if typeof key == "string" {
                let msgKey = field.".".key;
                let key = (isset maps[key]) ? maps[key] : key;
                if  in_array(key, ["_in", "notIn"]) {
                    if !call_user_func_array([this, key], [data, value]) {
                        if isset this->messages[msgKey] {
                            let this->errors[field]=this->messages[msgKey];
                        }else{
                            let this->errors[field]=field." is not valid";
                        }
                        return false;
                    }
                    continue;
                }
                if is_array(value) {
                    array_unshift(value, data);
                } else {
                    let value = [data, value];
                }
                if !call_user_func_array([this, key], value) {
                    let this->errors[field]=(isset this->messages[msgKey])?this->messages[msgKey]:field." is not valid";
                    return false;
                }
            } else {
                if !call_user_func([this, value], data) {
                    let msgKey = field.".".value;
                    let this->errors[field]=(isset this->messages[msgKey])?this->messages[msgKey]:field." is not valid";
                    return false;
                }
            }
        }
        return true;
    }

    /**
     * Get validate result
     *
     * @param array $data
     * @return bool
     */
    public function isValid(array! data = [])->bool
    {
        if !empty(data) {
            let this->data = data;
        }
        var field, rules;
        for field, rules in this->rules {
            if !this->validOne(field, (isset this->data[field])?this->data[field]:[], rules) {
                return false;
            }
        }
        return true;
    }

    /**
     * If empty
     *
     * @param string $value
     * @return bool
     */
    private function required(value)->bool
    {
        return !(empty(value) && !is_numeric(value));
    }

    /**
     * Email address
     * @param string $value
     * @return mixed
     */
    private function email(value)//->bool
    {
        let value = self::valueToString(value);
        return filter_var(value, FILTER_VALIDATE_EMAIL);
    }

    /**
     * Date string
     *
     * @param string $value
     * @param string $format
     * @return bool
     */
    private function date(value, format = "Y-m-d")->bool
    {
        return date(format, strtotime(value)) == value;
    }

    /**
     * Datetime string
     *
     * @param string $value
     * @param string $format
     * @return bool
     */
    private function datetime(value, format = "Y-m-d H:i:s")->bool
    {
        return date(format, strtotime(value)) == value;
    }

    /**
     * Alpha characters
     *
     * @param $value
     * @return false|int
     */
    private function alpha(value)//->bool
    {
        let value = self::valueToString(value);
        return preg_match("/^[a-z]+$/i", value);
    }

    /**
     * Alpha and number characters
     *
     * @param $value
     * @return false|int
     */
    private function alphaNum(value)//->bool
    {
        let value = self::valueToString(value);
        return preg_match("/^[a-z0-9]+$/i",value);
    }

    /**
     * Upper case alpha characters
     *
     * @param $value
     * @return false|int
     */
    private function upper(value)//->bool
    {
        let value = self::valueToString(value);
        return preg_match("/^[A-Z]+$/", value);
    }

    /**
     * If whitespace
     *
     * @param $value
     * @return false|int
     */
    private function isWhilespace(value)//->bool
    {
        let value = self::valueToString(value);
        return preg_match("/\s*/s", value);
    }

    /**
     * Lower case alpha characters
     *
     * @param $value
     * @return false|int
     */
    private function lower(value)//->bool
    {
        let value = self::valueToString(value);
        return preg_match("/^[a-z]+$/", value);
    }

    /**
     * IP address
     *
     * @param $value
     * @return false|int
     */
    private function ip(value)//->bool
    {
        return filter_var(value, FILTER_VALIDATE_IP);
    }

    /**
     * IPV4 address
     *
     * @param $value
     * @return false|int
     */
    private function ipv4(value)//->bool
    {
        return filter_var(value, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4);
    }

    /**
     * IPV6 address
     *
     * @param mixed $value
     * @return false|int
     */
    private function ipv6(value)//->bool
    {
        return filter_var(value, FILTER_VALIDATE_IP, FILTER_FLAG_IPV6);
    }

    /**
     * Is boolean value
     * @param mixed $value
     * @return bool
     */
    private function _bool(value)->bool
    {
        return !!is_bool(value);
    }

    /**
     * Alias of Integer
     *
     * @param $value
     * @return bool
     */
    private function _int(value)//->bool
    {
        if is_int(value) {
            return true;
        }elseif is_string(value) {
            return ctype_digit(value);
        }
        return false;
    }

    /**
     * Integer
     *
     * @param mixed $value
     * @return bool
     */
    private function _integer(value)->bool
    {
        return this->_int(value);
    }

    /**
     * Float
     *
     * @param mixed $value
     * @return bool
     */
    private function _float(value)->bool
    {
        return !!is_float(value);
    }

    /**
     * Numeric characters
     *
     * @param $value
     * @return bool
     */
    private function numeric(value)->bool
    {
        return !!is_numeric(value);
    }

    /**
     * array
     * @param $value
     * @return bool
     */
    private function _array(value)->bool
    {
        return !!is_array(value);
    }

    /**
     * Age
     * @param $value
     * @return bool
     */
    private function age(value)->bool
    {
        return (this->numeric(value) && value > 0 && value < 100);
    }

    /**
     * In validate
     *
     * @param $value
     * @param array $values
     * @return bool
     */
    private function _in(value,array values)->bool
    {
        return !!in_array(value, values);
    }

    /**
     * Not in validate
     *
     * @param $value
     * @param array $values
     * @return bool
     */
    private function notIn(value, array values)->bool
    {
        return !in_array(value, values);
    }

    /**
     * Greater than
     *
     * @param $value
     * @param $target
     * @return bool
     */
    private function gt(value, target)->bool
    {
        return value > target;
    }

    /**
     * Less than
     *
     * @param $value
     * @param $target
     * @return bool
     */
    private function lt(value, target)->bool
    {
        return value < target;
    }

    /**
     * Greater than or Equal
     *
     * @param $value
     * @param $target
     * @return bool
     */
    private function gte(value, target)->bool
    {
        return value >= target;
    }

    /**
     * Less than or Equal
     *
     * @param $value
     * @param $target
     * @return bool
     */
    private function lte(value, target)->bool
    {
        return value <= target;
    }

    /**
     * Equal
     *
     * @param $value
     * @param $target
     * @return bool
     */
    private function eq(value, target)->bool
    {
        return value == target;
    }

    /**
     * Value between
     *
     * @param $value
     * @param $min
     * @param $max
     * @return bool
     */
    private function between(value, min, max)->bool
    {
        return (value > min && value < max);
    }

    /**
     * Contain
     *
     * @param $value
     * @param $target
     * @return bool
     */
    private function contain(value, target)->bool
    {
        let target = (string) target;
        return false !== strpos(value, target);
    }

    /**
     * Not contain
     * @param $value
     * @param $target
     * @return bool
     */
    private function notContail(value, target)->bool
    {
        let target = (string) target;
        return false === strpos(value, target);
    }

    /**
     * String Length
     *
     * @param $value
     * @param $length
     * @return bool
     */
    private function length(value, length)->bool
    {
        let length = (int)length;
        return self::strlen(value)!==length;
    }

    /**
     * String minLength
     *
     * @param $value
     * @param $length
     * @return bool
     */
    private function minLength(value, length)->bool
    {
        var len;
        let length = (int) length;
        let len = self::strlen(value);
        return len >= length;
    }

    /**
     * String maxLength
     *
     * @param $value
     * @param $length
     * @return bool
     */
    private function maxLength(value, length)->bool
    {
        var len;
        let length = (int) length;
        let len = self::strlen(value);
        return len <= length;
    }

    /**
     * String Length between
     *
     * @param $value
     * @param $min
     * @param $max
     * @return bool
     */
    private function lengthBetween($value, $min, $max)->bool
    {
        var len;
        let min = (int) min;
        let max = (int) max;
        let len = self::strlen(value);
        return (len > min && len < max);
    }

    /**
     * Before a date or datetime
     *
     * @param $value
     * @param $target
     * @return bool
     */
    private function before(value, target)->bool
    {
        return strtotime(value) < strtotime(target);
    }

    /**
     * After a date or datetime
     *
     * @param string $value
     * @param string $target
     * @return bool
     */
    private function after(value, target)->bool
    {
        return strtotime(value) > strtotime(target);
    }

    /**
     * Date between
     *
     * @param mixed $value
     * @param mixed $begin
     * @param mixed $end
     * @return bool
     */
    private function dateBetween(value, begin, end)->bool
    {
        var time;
        let time  = strtotime(value);
        return (time > strtotime(begin) && time < strtotime(end));
    }

    /**
     * Value to string
     *
     * @param $value
     * @return string
     */
    private static function valueToString(value)->string
    {
        if null === value {
            return "null";
        }
        if true === value {
            return "true";
        }
        if false === value {
            return "false";
        }
        if is_array(value) {
            return "array";
        }
        if is_object(value) {
            if method_exists(value, "__toString") {
                return value->__toString();
            }
            return (string) get_class(value);
        }
        if is_resource(value) {
            return "resource";
        }
        if is_string(value) {
            return "\"".value."\"";
        }
        return (string) value;
    }

    /**
     * Get string length,Support UNICODE
     *
     * @param $value
     * @return int
     */
    public static function strlen(value)->int
    {
        if !function_exists("mb_detect_encoding") {
            return (int)strlen(value);
        }
        var encoding;
        let encoding = mb_detect_encoding(value);
        if false === encoding {
            return (int)strlen(value);
        }
        return (int)mb_strlen(value, encoding);
    }

    /**
     * Strict trim a string
     *
     * @param $str
     * @return string
     */
    public static function trimString(string! str)->string
    {
        if function_exists("mb_ereg_replace") {
            let str = mb_ereg_replace("^((\s)*(　)*)*", "", str);
            let str = mb_ereg_replace("((\s)*(　)*)*$", "", str);
        }
        let str = trim(str, "\x00..\x1F");
        let str = str_replace([
            "\xe2\x80\x8b",
            "\xe2\x80\x8c",
            "\xe2\x80\x8d",
            "\xe2\x80\xac",
            "\xe2\x80\xad"
        ],"", str);
        return (string)trim(str);
    }
}
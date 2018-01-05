namespace Aimo;
/**
 * Aimo\Model
 *
 * 模型基类
 */
class Model
{
    protected table   = "";
    protected prefix  = "";
    protected static primary = [];
    protected fields  = [];
    protected _data   = [];
    protected _rows   = [];
    protected _index  = 0;
    protected _validateRules = [];
    protected _error = [];

    /**
     * Aimo\Model
     *
     * 模型基类
     *
     *<code>
     * use Aimo\Model;
     * class User extends Model {
     *     protected $table = 'user';
     *     protected static $primary = ['uid'];
     *     protected $fields  = [
     *         'uid','username','password',
     *         'groupid','regtime'
     *     ];
     *     protected $validateRules = [
     *     ];
     *     
     *     protected function setPassword($value)
     *     {
     *         return md5($value);    
     *     }
     *     protected function getRegtime($value)
     *     {
     *            return date('Y-m-d H:i:s',$value);
     *     }
     * }
     * $user = new User();
     * $user->username = 'eric';
     * $user->password = '123456';
     * $user->save();
     *</code>
     */
    public function __construct()
    {}

    public function __set(string! name, value) -> void
    {
        var method;
        if !property_exists(this,name) {
            let method = "set".ucfirst(name);
            if method_exists(this, method) {
                let this->_data[name] = this->{method}(value);
            }else{
                let this->_data[name]=value;
            }
        }
    }

    public function __get(string! name)
    {
        var method;
        if !property_exists(this, name){
            let method = "get".ucfirst(name);
            if method_exists(this, method) {
                return this->{method}(this->_data[name]);
            }else{
                return this->_data[name];
            }
        }
        return null;
    }

    public function __toString()
    {
        return get_called_class();
    }

    public function toArray()
    {
        return this->_data;
    }

    public function getError()
    {
        return this->_error;
    }

    public function validate()
    {
        var messages,operate,key,value,validateFields,field;
        var ruleString,rules,rule,v,c,kk;
        array cond;
        let messages = this->_validateRules["msg"];
        let operate  = "update";
        for key in self::primary {
            let value = this->_data[key];
            if empty value {
                let operate = "create";
                break;
            }
        }

        if isset this->_validateRules["scene"] {
            if empty this->_validateRules["scene"][operate] {
                let validateFields = array_keys(this->_validateRules["rules"]);
            }else{
                let validateFields = this->_validateRules["scene"][operate];
            }
        }else{
            let validateFields = array_keys(this->_validateRules["rules"]);
        }

        for field in validateFields {
            let ruleString = this->_validateRules["rules"][field];
            let rules      = explode("|", ruleString);
            let v          = this->_data[field];
            for rule in rules {
                if strpos(rule, ":") === false {
                    if rule == "require" {
                        if empty v && v!==0 && v!=="0" {
                            let this->_error[]=messages[field.".".rule];
                            return false;
                        }
                    }elseif rule == "number" {
                        if !is_numeric(v) {
                            let this->_error[]=messages[field.".".rule];
                            return false;
                        }
                    }elseif rule == "integer" {
                        if (typeof v != "integer"){
                            let this->_error[]=messages[field.".".rule];
                            return false;
                        }
                    }elseif rule == "float" {
                        if !is_float(v) {
                            let this->_error[]=messages[field.".".rule];
                            return false;
                        }
                    }elseif rule == "email"{
                        if !filter_var(v, FILTER_VALIDATE_EMAIL) {
                            let this->_error[]=messages[field.".".rule];
                            return false;
                        }
                    }elseif rule == "alpha" {
                        if !preg_match("/^[a-z]+$/i",v) {
                            let this->_error[]=messages[field.".".rule];
                            return false;
                        }
                    }elseif rule == "alphaNum" {
                        if !preg_match("/^[a-z0-9]+$/i",v) {
                            let this->_error[]=messages[field.".".rule];
                            return false;
                        }
                    }elseif rule == "alphaDash" {
                        if !preg_match("/^[a-z0-9_]+$/i",v) {
                            let this->_error[]=messages[field.".".rule];
                            return false;
                        }
                    }elseif rule == "alphaDash" {
                        if !preg_match("/^[a-z0-9_]+$/i",v) {
                            let this->_error[]=messages[field.".".rule];
                            return false;
                        }
                    }elseif rule == "unique" {

                        if operate == "create" {

                            let c = self::where(field,v)->count();
                            if c > 0 {
                                let this->_error[]=messages[field.".".rule];
                                return false;
                            }

                        }elseif operate == "update" {
                            
                            let cond = [field:v];
                            for kk in self::primary {
                                let cond[kk]=["<>",this->{kk}];
                            }
                            let c = self::where(cond)->count();
                            if c>0 {
                                let this->_error[]=messages[field.".".rule];
                                return false;
                            }

                        }
                    }

                }else{

                    var ruleName,params,temp,length,minlength,maxlength,valid,begin,end;
                    let temp = explode(":", rule);
                    let ruleName = temp[0];
                    let params = explode(",", temp[1]);
                    switch ruleName
                    {
                        case "in":
                            if !in_array(v, params) {
                                let this->_error[]=messages[field.".".ruleName];
                                return false;
                            }
                            break;
                        case "notin":
                            if in_array(v, params) {
                                let this->_error[]=messages[field.".".ruleName];
                                return false;
                            }
                            break;
                        case "between":
                            if v < params[0] || v > params[1] {
                                let this->_error[]=messages[field.".".ruleName];
                                return false;
                            }
                            break;
                        case "notBetween":
                            if v >= params[0] && v <= params[1] {
                                let this->_error[]=messages[field.".".ruleName];
                                return false;
                            }
                            break;
                        case "length":
                            let length = strlen(v);
                            if count(params) == 1 {
                                if length != intval(params[0]) {
                                    let this->_error[]=messages[field.".".ruleName];
                                    return false;
                                }
                            }else{
                                let minlength = intval(params[0]);
                                let maxlength = intval(params[1]);
                                if length < minlength || length > maxlength {
                                    let this->_error[]=messages[field . "." . ruleName];
                                    return false;
                                }
                            }
                            break;
                        case "max":
                            if v > params[0] {
                                let this->_error[]=messages[field.".".ruleName];
                                return false;
                            }
                            break;
                        case "min":
                            if v < params[0]{
                                let this->_error[]=messages[field.".".ruleName];
                                return false;
                            }
                            break;
                        case "after":
                            let v = strtotime(v);
                            let valid = strtotime(params[0]);
                            if v < valid {
                                let this->_error[]=messages[field.".".ruleName];
                                return false;
                            }
                            break;
                        case "before":
                            let v = strtotime(v);
                            let valid = strtotime(params[0]);
                            if v > valid {
                                let this->_error[]=messages[field.".".ruleName];
                                return false;
                            }
                            break;
                        case "expire":
                            let v = strtotime(v);
                            let begin = strtotime(params[0]);
                            let end   = strtotime(params[1]);
                            if v < begin || v > end {
                                let this->_error[]=messages[field.".".ruleName];
                                return false;
                            }
                            break;
                        case "confirm":
                            if v !== params[0] {
                                let this->_error[]=messages[field.".".ruleName];
                                return false;
                            }
                            break;
                        case "regex":
                            if !preg_match(params[0], v){
                                let this->_error[]=messages[field.".".ruleName];
                                return false;
                            }
                            break;
                        case "unique":
                            if operate == "create" {
                                let c = self::where(field,v)->count();
                                if c>0 {
                                    let this->_error[]=messages[field.".".ruleName];
                                    return false;
                                }
                            }elseif operate == "update" {
                                let cond = [field:v];
                                for kk in self::primary{
                                    let cond[kk]=["<>",this->{kk}];
                                }
                                let c = self::where(cond)->count();
                                if c>0 {
                                    let this->_error[]=messages[field.".".ruleName];
                                    return false;
                                }
                            }
                            break;
                    }
                }
            }
        }
        return true;
    }

    public function isValid()
    {
        return this->validate();
    }

    /**
     * 模型查询入口
     *
     * <code php>
     * User::where("uid=1");
     * User::where("uid",1);
     * User::where("uid=?",[1]);
     * User::where("uid","=",1);
     * User::where("uid","IN",[1,4]);
     * User::where(["uid"=>1,"status"=>1]);
     * User::where(["uid"=>1,"status"=>["<>",1]]);
     * User::where("status",1)->orderByDesc('sort')->groupBy('guid')->select();
     * </code>
     */
    public static function where(a,b=null,c=null)
    {
        var model,table;
        let model = get_called_class();
        if strpos(model, "\\") !== false {
            let table = substr(strrpos(model, "\\"), 1);
        }
        return Db::name(table)->setEntity(model,self::primary)->where(a,b,c);
    }

    /**
     * 获取单条信息
     *
     *<code>
     *$user = User::get(6);
     *echo $user->username;
     *</code>
     *
     * @access public
     * @parma integer|string id
     * @return Model
     */
    public static function get(id)
    {
        if empty self::primary {
            throw "Model Primary not defined.Can't use Model::get method";
        }
        if count(self::primary) > 1 {
            throw "Model Multiple Primary not supported yet.";
        }
        var model,table;
        let model = get_called_class();
        if strpos(model, "\\") !== false {
            let table = substr(strrpos(model, "\\"), 1);
        }
        return Db::name(table)->setEntity(model,self::primary)->where(self::primary[0],id)->find();
    }

    /**
     * 新增模型数据
     *
     *<code>
     *$user = new User();
     *$user->username = 'eric';
     *$user->password = '123456';
     *$user->save();
     *</code>
     *
     * @access public
     * @return Model
     */
    public function save()
    {
        var model,table,id;
        let model = get_called_class();
        if strpos(model, "\\") !== false {
            let table = substr(strrpos(model, "\\"), 1);
        }
        if this->isValid() {
            if !empty self::primary && count(self::primary)===1 {
                let id = Db::name(table)->insertGetId(this->_data);
                let this->_data[self::primary[0]] = id;
                return true;
            }else{
                return Db::name(table)->insert(this->_data);
            }
        } else {
            return false;
        }
    }

    /**
     * 更新模型数据
     *
     *<code>
     *$user = User::get(6);
     *$user->lastlogin = time();
     *$user->update();
     *</code>
     *
     * @access public
     */
    public function update()
    {
        if empty self::primary {
            throw "Model Primary not defined.Can't use Model::update method";
        }
        array cond = [];
        var model,table,k;
        for k in self::primary {
            let cond[k]=this->_data[k];
            unset this->_data[k];
        }
        let model = get_called_class();
        if strpos(model, "\\") !== false {
            let table = substr(strrpos(model, "\\"), 1);
        }
        if this->isValid(){
            return Db::name(table)->where(cond)->update(this->_data);
        }else{
            return false;
        }
    }

    /**
     * 软删除
     *
     *<code>
     *$user = User::get(6);
     *$user->delete();
     *</code>
     *
     * @access public
     */
    public function delete(field="status",value=-1)
    {
        if empty self::primary {
            throw "Model Primary not defined.Can't use Model::delete method";
        }
        array cond = [];
        var model,table,k;
        for k in self::primary {
            let cond[k]=this->_data[k];
        }
        let model = get_called_class();
        if strpos(model, "\\") !== false {
            let table = substr(strrpos(model, "\\"), 1);
        }
        let this->_data[field]=value;
        return Db::name(table)->where(cond)->update([field:value]);
    }

    /**
     * 硬删除/彻底删除
     *
     *<code>
     *$user = User::get(6);
     *$user->destroy();
     *</code>
     *
     * @access public
     */
    public function destroy()
    {
        if empty self::primary {
            throw "Model Primary not defined.Can't use Model::destroy method";
        }
        var model,table,k,rs,returnValue;
        array cond = [];
        for k in self::primary {
            let cond[k]=this->_data[k];
        }
        let model = get_called_class();
        if strpos(model, "\\") !== false {
            let table = substr(strrpos(model, "\\"), 1);
        }
        let returnValue = Event::trigger("beforeDestroy",[this->_data,this]);
        if returnValue === false {
            return false;
        }
        let rs = Db::name(table)->where(cond)->delete();
        Event::trigger("afterDestroy",[this->_data,this]);
        return rs;
    }
}
namespace Aimo;
/**
 * Aimo\Model
 *
 * 模型基类
 */
class Model
{
    /**
     *@var string 模型名
     */
    protected modelName = "";

    /**
     *@var string 数据表名
     */
    protected table     = "";

    /**
     *@var array primary 模型主键
     */
    protected primary   = [];

    /**
     *@var array validateRules 验证规则
     */
    protected validateRules = [];

    /**
     *@var primary 模型主键
     */
    protected fields    = [];

    /**
     *@var array 数据
     */
    protected _data     = [];


    /**
     *@var array 更新的数据
     */
    protected _dirty     = [];
    /**
     *@var array 数据集
     */
    protected _rows     = [];

    /**
     *@var int 索引
     */
    protected _index    = 0;

    /**
     *@var array 模型错误信息
     */
    protected _error    = [];

    /**
     * Aimo\Model
     *
     * 模型基类
     *
     *<code>
     * use Aimo\Model;
     * class User extends Model {
     *     protected $table = 'user';
     *     protected $primary = ['uid'];
     *     protected $fields  = [
     *         'uid','username','password',
     *         'groupid','regtime'
     *     ];
     *     protected $validateRules = [
     *          'rules'  => [
     *              'comid'   => 'require|number',
     *              'uid'     => 'require|number',
     *              'content' => 'require',
     *              'time'    => 'require|number'
     *          ],
     *          'msg'   => [
     *              'comid.require'   => '必须指定企业ID',
     *              'comid.number'    => '必须指定企业ID',
     *              'uid.require'     => '登陆后操作',
     *              'uid.number'      => '登陆后操作',
     *              'content.require' => '笔记内容必须填写',
     *              'time.require'    => '记录时间必须设置',
     *              'time.number'     => '记录时间必须设置',
     *          ],
     *          'scene' => [
     *              'create' =>  ['comid','uid','content','time'],
     *              'update' =>  ['content','time']
     *          ]
     *     ];
     *     
     *     protected function setPassword($value)
     *     {
     *         return md5($value);    
     *     }
     *     protected function getRegtime($value)
     *     {
     *         return date('Y-m-d H:i:s',$value);
     *     }
     * }
     * $user = new User();
     * $user->username = 'eric';
     * $user->password = '123456';
     * $user->save();
     *</code>
     */             
    public function __construct()
    {
    }

    /**
     *Judge if the operation is Create or Update
     */
    protected function isNew()->boolean
    {
        var pks,pk;
        let pks = this->getPk();
        for pk in pks {
            if isset this->_data[pk] && !empty this->_data[pk] {
                return false;
            }
        }
        return true;
    }

    /**
     * 魔术方法设置模型数据
     */
    public function __set(string! name, value) -> void
    {
        var method;
        if !property_exists(this,name) {
            let method = "set".ucfirst(name);
            if method_exists(this, method) {
                if !isset this->_data[name] {
                    let this->_data[name] = this->{method}(value);
                }else{
                    let this->_dirty[name] = this->{method}(value);
                }
            }else{
                if !isset this->_data[name] {
                    let this->_data[name]=value;
                }else{
                    let this->_dirty[name]=value;
                }
            }
        }
    }

    public function __get(string! name)
    {
        var method,value;
        if !property_exists(this, name){
            let method = "get".ucfirst(name);
            let value = isset this->_dirty[name] ? 
                    this->_dirty[name] : isset this->_data[name] ? this->_data[name] : null;
            if method_exists(this, method) {
                return this->{method}(value);
            }else{
                return value;
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

    public function getPk()
    {
        return this->primary;
    }

    public function validate()
    {
        var messages,operate,key,value,validateFields,field,pks;
        var ruleString,rules,rule,v,c,kk;
        array cond;
        let messages = this->validateRules["msg"];
        let operate  = "update";
        let pks = this->getPk();
        for key in pks {
            let value = isset this->_data[key] ? this->_data[key] : "";
            if empty value {
                let operate = "create";
                break;
            }
        }

        if isset this->validateRules["scene"] {
            if empty this->validateRules["scene"][operate] {
                let validateFields = array_keys(this->validateRules["rules"]);
            }else{
                let validateFields = this->validateRules["scene"][operate];
            }
        }else{
            let validateFields = array_keys(this->validateRules["rules"]);
        }

        for field in validateFields {
            let ruleString = this->validateRules["rules"][field];
            let rules      = explode("|", ruleString);
            let v          = isset this->_data[field] ? this->_data[field] : null;
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
                    }elseif rule == "int" {
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
                    }elseif rule == "unique" {

                        if operate == "create" {

                            let c = self::where(field,v)->count();
                            if c > 0 {
                                let this->_error[]=messages[field.".".rule];
                                return false;
                            }

                        }elseif operate == "update" {
                            
                            let cond = [field:v];
                            for kk in pks {
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
                                for kk in pks {
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
        var model,table,instance,pks;
        let model = get_called_class();
        if strpos(model, "\\") === false {
            let table = model;
        }else{
            let table = substr(strrchr(model, "\\"), 1);
        }
        let instance  = new {model}();
        let pks       = (array) instance->getPk();
        let instance  = null;
        return Db::name(table)->setEntity(model, pks)->where(a,b,c);
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
        var model,table,instance,pks;
        let model = get_called_class();
        if strpos(model, "\\") === false {
            let table = model;
        }else{
            let table = substr(strrchr(model, "\\"), 1);
        }
        let instance  = new {model}();
        let pks       = (array) instance->getPk();
        let instance  = null;
        if empty pks {
            throw "Model Primary not defined.Can't use Model::get method";
        }
        if count(pks) > 1 {
            throw "Model Multiple Primary not supported yet.";
        }
        return Db::name(table)->setEntity(model,pks)->where(pks[0],id)->find();
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
        var model,table,id,pks,pk;
        let model = get_called_class();
        if strpos(model, "\\") === false {
            let table = model;
        }else{
            let table = substr(strrchr(model, "\\"), 1);
        }
        let pks = (array) this->getPk();
        if this->isValid() {
            if !empty pks && count(pks)===1 {
                let id = Db::name(table)->insertGetId(this->_data);
                let pk = pks[0];
                let this->_data[pk] = id;
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
        array cond = [];
        var model,table,k,pks;
        let model = get_called_class();
        if strpos(model, "\\") === false {
            let table = model;
        }else{
            let table = substr(strrchr(model, "\\"), 1);
        }
        let pks  = (array) this->getPk();
        if empty pks {
            throw "Model Primary not defined.Can't use Model::update method";
        }
        for k in pks {
            if isset this->_data[k] {
                let cond[k]=this->_data[k];
                unset this->_data[k];
            }
        }
        if empty cond {
            throw "Model data error,No primary value given";
        }
        
        if this->isValid(){
            return Db::name(table)->where(cond)->update(this->_dirty);
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
    public function delete(string! field="status",value=-1)
    {
        array cond = [];
        var model,table,k,pks;
        let model  = get_called_class();
        if strpos(model, "\\") === false {
            let table = model;
        }else{
            let table = substr(strrchr(model, "\\"), 1);
        }
        let pks = (array) this->getPk();
        if empty pks {
            throw "Model Primary not defined.Can't use Model::delete method";
        }
        for k in pks {
            let cond[k]=this->_data[k];
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
        var model,table,k,rs,pks,returnValue;
        array cond = [];
        let model  = get_called_class();
        if strpos(model, "\\") === false {
            let table = model;
        }else{
            let table = substr(strrchr(model, "\\"), 1);
        }
        let pks = (array) this->getPk();
        if empty pks {
            throw "Model Primary not defined.Can't use Model::destroy method";
        }
        for k in pks {
            let cond[k]=this->_data[k];
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
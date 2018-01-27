namespace Aimo;
use Aimo\Db\Helper;
class Db
{
    protected static _default_config = [
        "dsn" : "",
        "primary" : "id",
        "primary_map" : [],
        "error_mode" : \PDO::ERRMODE_EXCEPTION,
        "username" : null,
        "password" : null,
        "options" : null,
        "prefix" : "",
        "quote" : null,
        "id_case" : "lower",//lower,upper,default
        "limit_style" : null,
        "logging" : false,
        "logger" : null
    ];
    protected static _config = [];
    protected static _db = [];
    protected static _last_query;
    protected static _query_log = [];
    protected static _last_statement = null;
    /**
     * 链接名称
     */
    protected _name;
    protected _table_name;
    protected _table_alias = null;
    protected _values = [];
    protected _fields = ["*"];
    protected _using_default_fields = true;
    protected _join_sources = [];
    protected _distinct = false;
    protected _is_raw_query = false;
    protected _raw_query = "";
    protected _raw_parameters = [];
    protected _where_conditions = [];
    protected _limit = null;
    protected _offset = null;
    protected _order_by = [];
    protected _group_by = [];
    protected _having_conditions = [];
    protected _data = [];
    protected _expr_fields = [];
    protected _instance_pk = null;

    //强制返回数组结果
    protected _as_array = false;

    //绑定的模型
    protected _entity = null;
    /**
     * 避免DB被直接实例化
     */
    protected function __construct(string! table,array! data = [],string! name = "default")
    {
        let this->_table_name = table;
        let this->_data = data;
        let this->_name = name;
        self::initConfig(name);
    }

    /**
     * 单项设置
     *
     * 逐个设置配置项
     *
     * <code>
     * Db::config('username','username');
     * Db::config('password','password');
     * Db::config('options',[\PDO::MYSQL_ATTR_INIT_COMMAND => 'SET NAMES utf8']);
     * </code>
     *
     * @access public
     * @param string $key
     * @param mixed $value
     * @param string $name 那个链接
     */
    public static function config(string! key, value = null,string! name = "default")
    {
        let self::_config[name][key] = value;
    }

    /**
     * 初始化数据库配置
     *
     * PDO数据库配置项
     *
     * <code>
     * Aimo\Db::init([
     *     'dsn' => 'mysql:host=localhost;dbname=database',
     *     'username' => 'username',
     *     'password' => 'password',
     *     'prefix'   => 'prefix_',//Table prefix
     *     'options'  => [
     *           \PDO::MYSQL_ATTR_INIT_COMMAND => 'SET NAMES utf8'
     *     ]
     * ]);
     * </code>
     *
     * @access public
     * @param array config 配置数组
     * @return void;
     */
    public static function init(array! config,string! name = "default") -> void
    {
        if empty config {
            throw "Db config can't empty";
        }
        if (typeof config != "array") {
            throw "Db config must be a array";
        }
        self::initConfig(name);
        var k,v;
        for k,v in config {
            if isset self::_config[name][k] {
                self::config(k, v, name);
            }
        }
    }

    /**
     * 读取数据库配置
     *
     * <code>
     * //value
     * Db::getConfig('username');
     * //array
     * Db::getConfig('username');
     * </code>
     *
     * @access public
     * @param string $key
     * @param string $name Which connection to use
     */
    public static function getConfig(string! key = null,string! name = "default")
    {
        if !empty key {
            return self::_config[name][key];
        } else {
            return self::_config[name];
        }
    }

    /**
     * 重置配置项
     *
     * <code>
     * Db::resetConfig();
     * </code>
     *
     * @access public
     */
    public static function resetConfig() -> void
    {
        let self::_config = [];
    }

    /**
     * 基于数据表的虚拟模型进行数据访问
     *
     * <code>
     * Db::table('user')->find();
     * </code>
     *
     * @access public
     * @param string $table_name 表的全名
     * @param string $name Which connection to use
     * @return Db
     */
    public static function table(string! table,string! name = "default") -> <Db>
    {
        self::initConfig(name);
        var fcase;
        if fetch fcase, self::_config["id_case"] {
            if fcase == "upper" {
                let table = table->upper();
            } elseif fcase == "lower" {
                let table = table->lower();
            }
        }
        //self::connect(name);
        return new self(table, [], name);
    }

    /**
     * 基于数据表的虚拟模型进行数据访问
     *
     * <code>
     * Db::name('user')->find();
     * </code>
     *
     * @access public
     * @param string $table_name 不含前缀的表名 （前提是在config中设置了prefix参数）
     * @param string $name Which connection to use
     * @return Db
     */
    public static function name(string! table,string! name = "default") -> <Db>
    {
        self::initConfig(name);
        string prefix;
        var fcase;
        let prefix = (string) self::getConfig("prefix",name);
        if fetch fcase,self::_config["id_case"] {
            if fcase == "upper" {
                let table = table->upper();
            } elseif fcase == "lower" {
                let table = table->lower();
            }
        }
        //self::connect(name);
        return new self(prefix.table, [], name);
    }

    /**
     * 设置PDO链接
     *
     * @access public
     * @param PDO $db
     * @param string $name Which connection to use
     */
    public static function setDb(<\PDO> db,string! name = "default") -> void
    {
        self::initConfig(name);
        let self::_db[name] = db;
        if (typeof self::_db[name] != "null") {
            self::setQuote(name);
            self::setLimitStyle(name);
        }
    }

    /**
     * 获取PDO实例
     *
     * <code>
     * $pdo = Db::getDb();
     * $pdo = Db::getDb('name');//多数据库实例时通过name指定
     * </code>
     *
     * @access public
     * @param string $name Which connection to use
     * @return PDO
     */
    public static function getDb(string! name = "default") -> <\PDO>
    {
        self::connect(name);//required in case this is called before ORM is instantiated
        return self::_db[name];
    }

    /**
     * 删除已注册的PDO链接对象
     *
     * @access public
     */
    public static function resetDb() -> void
    {
        let self::_db = [];
    }

    /**
     * 绑定模型到查询出的数据
     *
     * 本方法在Aimo\Model中调用，并根据called class 实例化模型类
     *
     */
    public function setEntity(string! klass,array! primary) -> <Db>
    {
        let this->_entity  = klass;
        if (typeof primary == "array") {
            if count(primary) === 1 {
                self::config("primary", primary[0]);
            }else{
                self::config("primary", primary);
            }
        }
        return this;
    }

    /**
     * 执行原生查询
     *
     * <code>
     * Db::query("SELECT `name`, AVG(`order`) FROM `customer` GROUP BY `name` HAVING AVG(`order`) > 10")
     * Db::query("INSERT OR REPLACE INTO `widget` (`id`, `name`) SELECT `id`, `name` FROM `other_table`")
     * </code>
     *
     * @access public
     * @param string $query SQL语句
     * @param array  $parameters 绑定的变量
     * @param string $name 默认数据链接
     * @return bool
     */
    public static function query(string! query, parameters = [], name = "default")
    {
        self::connect(name);
        return self::_execute(query, parameters, name);
    }

    /**
     * 返回最后一次使用的PDOStatement实例
     * 方便调用PDOStatement::rowCount()或者获取错误
     *
     *<code>
     *Db::getLastStatement();
     *</code>
     *
     * @access public
     * @return PDOStatement
     */
    public static function getLastStatement() -> <\PDOStatement>
    {
        return self::_last_statement;
    }


    /**
     * 获取最后执行的一句SQL
     *
     * @access public
     * @return string
     */
    public function getLastSql()
    {
        return self::getLastQuery();
    }

    /**
     * 获取执行的最后一条SQL
     *
     *<code>
     *Db::getLastQuery();
     *Db::getLastQuery('default');
     *</code>
     *
     * @access public
     * @param null|string $name Which connection to use
     * @return string
     */
    public static function getLastQuery(name = null)
    {
        if name === null {
            return self::_last_query;
        }
        if !isset self::_query_log[name] {
            return "";
        }

        return end(self::_query_log[name]);
    }

    /**
     * Get an array containing all the queries run on a
     * specified connection up to now.
     * Only works if the "logging" config option is
     * set to true. Otherwise, returned array will be empty.
     * @param string $name Which connection to use
     */
    public static function getQueryLog(string! name = "default")
    {
        if isset self::_query_log[name] {
            return self::_query_log[name];
        }
        return [];
    }

    /**
     * 列出可用的PDO链接
     *
     *<code>
     * Db::getConnectionNames();
     *</code>
     *
     * @return array
     */
    public static function getConnectionNames()
    {
        return array_keys(self::_db);
    }

    /**
     * 为当前表指定别名
     *
     * <code>
     * Db::table('user')->alias('u')->where('u.uid',3)->find();
     * </code>
     *
     * @access public
     * @return Db
     */
    public function alias(string! alias) -> <Db>
    {
        let this->_table_alias = alias;
        return this;
    }

    /**
     * 指定查询的字段
     *
     * Note that the alias must not be numeric - if you want a
     * numeric alias then prepend it with some alpha chars. eg. a1
     *
     * <code>
     * //Right example
     * Db::table('user')->fields('uid,username,password')->...;
     * Db::table('user')->fields('uid,username,password as hash')->...;
     * Db::table('logs')->fields('uid,COUNT(*) as count')->...;
     * Db::table('user')->fields('uid,username',['amount'=>'SUM(`fee`)'])->...;
     * //Wrong example
     * //Do not use SQL Function contain "," syntax,it will be cause sql error;
     * Db::table('user')->field('uid,CONCAT(roleid,"_",departmentid) as rel');
     * </code>
     *
     * @access public
     * @return <Db>
     */
    public function fields() -> <Db>
    {
        var columns,alias,column,fields,aliass,field,parts;
        let columns = func_get_args();
        if !empty columns {
            for alias,column in columns {
                if (typeof column == "string") {
                    if strpos(column, ",")!== false {
                        let fields = explode(",", column);
                        for field in fields {
                            if stripos(field," as ") !== false {
                                let parts  = explode(" AS ", str_ireplace(" as ", " AS ", field));
                                let field  = this->trimField(parts[0]);
                                let aliass = this->trimField(parts[1]);
                                if strpos(field,"(") !== false {
                                    this->fieldExpr(field, aliass);
                                } else {
                                    this->field(field, aliass);
                                }
                            }else{
                                let field = this->trimField(field);
                                this->field(field);
                            }
                        }
                    }else{
                        let column = this->trimField(column);
                        this->field(column);
                    }
                } elseif (typeof column == "array"){
                    for alias,field in column {
                        if strpos(field,"(") !== false {
                            if is_numeric(alias) {
                                this->fieldExpr(field);
                            } else {
                                this->fieldExpr(field,alias);
                            }
                        } else {
                            if is_numeric(alias) {
                                this->field(field);
                            } else {
                                this->field(field,alias);
                            }
                        }
                    }
                }
            }
        }
        return this;
    }

    /**
     * 在SELECT查询前添加 DISTINCT 关键字
     */
    public function distinct()-><Db>
    {
        let this->_distinct = true;
        return this;
    }

    /**
     * 连表查询方法
     *
     *<code>
     * Db::name('user')->join('profile','user.uid=profile.uid','RIGHT')->select();
     *</code>
     *
     * @access public
     * @param string table 表名
     * @param string|array ON条件
     * @param string joinType 链接方式，支持 LEFT,RIGHT,INNER,FULL
     */
    public function join(string! table,var constraint,joinType="LEFT", table_alias=null)
    {
        string types = "_LEFT_RIGHT_INNER_FULL_";
        let joinType = strtoupper(joinType);
        if types->index("_".joinType."_") {
            return this->_add_join_source(joinType, table, constraint, table_alias);
        }
        throw "Unsupported JOIN TYPE";
    }

    /**
     * Add a RAW JOIN source to the query
     */
    public function rawJoin(table, constraint, table_alias = null, parameters = [])
    {
        var first_column,operator,second_column;
        if table_alias != null {
            let table_alias = this->quoteId(table_alias);
            let table = table." ".table_alias;
        }

        let this->_values = array_merge(this->_values, parameters);

        if (typeof constraint == "array")  {
            let first_column  = this->quoteId(constraint[0]);
            let operator      = this->quoteId(constraint[1]);
            let second_column = this->quoteId(constraint[2]);
            let constraint  = first_column." ".operator." ".second_column;
        }

        let this->_join_sources[] = table." ON ".constraint;
        return this;
    }

    /**
     * WHERE条件
     *
     * <code>
     * Db::table('user')->where('uid=3')->find();
     * Db::table('user')->where('uid=?',[3])->find();
     * //>,<,!=,<>,>=,<=
     * Db::table('user')->where('uid','=',3)->find();
     * //Default login is AND
     * Db::table('user')->where([
     *     'groupid' => 2,
     *     'role' => ['<>','editor'],
     *     'name' => ['LIKE', 'test%'],
     * ])->select();
     * </code>
     * @access public
     */
    public function where(a,b=null,c=null)
    {
        var k,v;
        string operators;
        if b==null && c==null {
            if (typeof a=="string" ) {
                return this->whereRaw(a);
            } elseif (typeof a == "array") {
                for k,v in a {
                    if !is_numeric(k) {
                        if (typeof v=="array") {
                            if count(v) === 2 {
                                this->simpleWhere(k,v[0],v[1]);
                            }
                        } else {
                            this->whereEqual(k,v);
                        }
                    }
                }
                return this;
            }
        } elseif b!=null && c==null {
            if (typeof a == "array"){
                throw "Not support conditon defination";
            } elseif (typeof a == "string") {
                if (typeof b == "array") {
                    return this->whereRaw(a,b);
                }elseif is_int(b) || is_float(b) || (typeof b == "string") {
                    return this->whereEqual(a,b);
                }
            }
        } elseif  b!=null && c!=null {
            let operators = "_=_!=_>_<>_<_>=_<=_LIKE_NOT LIKE_";
            if (typeof b == "string"){
                let b = strtoupper(b);
                if operators->index("_".b."_") {
                    return this->simpleWhere(a, b, c);
                }
                if strcasecmp(b,"in") === 0 {
                    return this->_add_where_placeholder(a, "IN", c);
                }
                if strcasecmp(b,"not in") === 0 {
                    return this->_add_where_placeholder(a, "NOT IN", c);
                }
            }
        }
        trigger_error("where method execute failed", E_USER_NOTICE);
        return this;
    }

    /**
     * 条件等于
     *
     *<code>
     *Db::name('table')->whereEqual('field','value')->find();
     *</code>
     *
     * @access public
     * @param string field 字段名
     * @param string|int|float value
     */
    public function whereEqual(field, value=null)
    {
        return this->simpleWhere(field, "=", value);
    }

    /**
     * 条件不等于
     *
     *<code>
     *Db::name('table')->whereNotEqual('field','value')->find();
     *</code>
     *
     * @access public
     * @param string field 字段名
     * @param string|int|float value
     */
    public function whereNotEqual(field, value=null)
    {
        return this->simpleWhere(field, "!=", value);
    }

    /**
     * Special method to query the table by its primary key
     *
     *<code>
     *Db::name('table')->whereIdIs('field','value')->find();
     *</code>
     *
     * @access public
     * @param string field 字段名
     * @param string|int|float value
     */
    public function whereIdIs(id)
    {
        return is_array(this->getPk()) ?
            this->where(this->getPkValue(id), null) :
            this->where(this->getPk(), id);
    }

    /**
     * 任意条件命中
     */
    public function whereAnyIs(values, operator="=")
    {
        array data = [];
        array query = ["(("];
        boolean first = true;
        boolean firstsub = true;
        var value,key,item,op;
        for value in values {
            if first {
                let first = false;
            } else {
                let query[] = ") OR (";
            }
            for key,item in value {
                let op = (typeof operator=="string") ? operator : (isset operator[key] ? operator[key] : "=");
                if firstsub {
                    let firstsub = false;
                } else {
                    let query[] = "AND";
                }
                let query[] = this->quoteId(key);
                let data[] = item;
                let query[] = op . " ?";
            }
        }
        let query[] = "))";
        return this->whereRaw(query->join(" "), data);
    }

    /**
     * 支持联合主键的where in
     *
     * <code>
     * $data = Db::table('table')->whereIdIn(['uid'=>3,'tagid'=>5]);
     * </code>
     */
    public function whereIdIn(ids)
    {
        return is_array(this->getPk()) ?
            this->whereAnyIs(this->getPkValues(ids)) :
            this->whereIn(this->getPk(), ids);
    }

    /**
     * LIKE 方法
     *
     * <code>
     * $data = Db::table('table')->whereLike('name','keyword%');
     * </code>
     */
    public function whereLike(field, value=null)
    {
        return this->simpleWhere(field, "LIKE", value);
    }

    /**
     * Add where WHERE ... NOT LIKE clause to your query.
     *
     * <code>
     * $data = Db::table('table')->whereNotLike('name','keyword%');
     * </code>
     */
    public function whereNotLike(field, value=null)
    {
        return this->simpleWhere(field, "NOT LIKE", value);
    }

    /**
     * Add a WHERE ... > clause to your query
     *
     * <code>
     * $data = Db::table('table')->whereGt('score',60);
     * </code>
     */
    public function whereGt(field, value=null)
    {
        return this->simpleWhere(field, ">", value);
    }

    /**
     * Add a WHERE ... < clause to your query
     *
     **<code>
     * $data = Db::table('table')->whereLt('score',60);
     * </code>
     */
    public function whereLt(field, value=null)
    {
        return this->simpleWhere(field, "<", value);
    }

    /**
     * Add a WHERE ... >= clause to your query
     *
     * <code>
     * $data = Db::table('table')->whereGte('score',60);
     * </code>
     */
    public function whereGte(field, value=null)
    {
        return this->simpleWhere(field, ">=", value);
    }

    /**
     * Add a WHERE ... <= clause to your query
     *
     * <code>
     * $data = Db::table('table')->whereLte('score',60);
     * </code>
     */
    public function whereLte(field, value=null)
    {
        return this->simpleWhere(field, "<=", value);
    }

    /**
     * Add a WHERE ... IN clause to your query
     *
     * <code>
     * $data = Db::table('table')->whereIn('field',['a','b','c']);
     * </code>
     */
    public function whereIn(field, values)
    {
        return this->_add_where_placeholder(field, "IN", values);
    }

    /**
     * Add a WHERE ... NOT IN clause to your query
     *
     * <code>
     * $data = Db::table('table')->whereNotIn('field',['a','b','c']);
     * </code>
     */
    public function whereNotIn(field, values)
    {
        return this->_add_where_placeholder(field, "NOT IN", values);
    }

    /**
     * Add a WHERE column IS NULL clause to your query
     *
     * <code>
     * $data = Db::table('table')->whereIsNull('field');
     * </code>
     */
    public function whereIsNull(field)
    {
        return this->_add_where_no_value(field, "IS NULL");
    }

    /**
     * Add a WHERE column IS NOT NULL clause to your query
     *
     * <code>
     * $data = Db::table('table')->whereNotNull('field');
     * </code>
     */
    public function whereNotNull(field)
    {
        return this->_add_where_no_value(field, "IS NOT NULL");
    }

    /**
     * Add a raw WHERE clause to the query. The clause should
     * contain question mark placeholders, which will be bound
     * to the parameters supplied in the second argument.
     *
     * <code>
     * $data = Db::table('table')->whereRaw('field1 = ? and field2 <> ?',['value1','value2']);
     * </code>
     */
    public function whereRaw(clause, parameters=[])
    {
        return this->_add_where(clause, parameters);
    }

    /**
     * 排序
     *
     *<code>
     * Db::name('user')->order('uid','DESC')->select();
     * //Quote idenfider your self
     * Db::name('user')->order('`uid` asc,`gid` DESC')->select();
     *</code>
     *
     *@access public
     *@param string field 字段名
     */
    public function order(string! order,string! type = "")
    {
        if empty type {
            let this->_order_by[] = order;
        } else {
            this->_add_order_by(order ,type);
        }
        return this;
    }

    /**
     * 倒序排列
     *
     *<code>
     * Db::name('user')->orderByDesc('uid')->select();
     *</code>
     *
     *@access public
     *@param string field 字段名
     */
    public function orderByDesc(field) -> <Db>
    {
        return this->_add_order_by(field, "DESC");
    }

    /**
     * 正序排列
     *
     *<code>
     * Db::name('user')->orderByAsc('uid')->select();
     *</code>
     *
     *@access public
     *@param string field 字段名
     */
    public function orderByAsc(field) -> <Db>
    {
        return this->_add_order_by(field, "ASC");
    }

    /**
     * 添加不被符号包围的表达式排序方式
     *
     *<code>
     * Db::name('user')->orderByExpr('RAND()')->select();//MySQL RAND()
     *</code>
     *
     *@access public
     *@param string clause 表达式
     */
    public function orderByExpr(string! clause) -> <Db>
    {
        let this->_order_by[] = clause;
        return this;
    }

    /**
     * 结果分组
     *
     *<code>
     * Db::name('user')->groupBy('groupid')->select();
     *</code>
     *
     *@access public
     *@param string field 字段名
     */
    public function groupBy(field) -> <Db>
    {
        let field = this->quoteId(field);
        let this->_group_by[] = field;
        return this;
    }

    /**
     * 表达式结果分组
     *
     *<code>
     * Db::name('user')->groupBy('groupid')->select();
     *</code>
     *
     *@access public
     *@param string expr 表达式
     */
    public function groupByExpr(string! expr) -> <Db>
    {
        let this->_group_by[] = expr;
        return this;
    }

    /**
     * Add a HAVING column = value clause to your query. Each time
     * this is called in the chain, an additional HAVING will be
     * added, and these will be ANDed together when the final query
     * is built.
     *
     * If you use an array in $field, a new clause will be
     * added for each element. In this case, $value is ignored.
     */
    public function having(field, value=null)
    {
        return this->havingEqual(field, value);
    }

    /**
     * More explicitly named version of for the having() method.
     * Can be used if preferred.
     */
    public function havingEqual(field, value=null)
    {
        return this->simpleHaving(field, "=", value);
    }

    /**
     * Add a HAVING column != value clause to your query.
     */
    public function havingNotEqual(field, value=null)
    {
        return this->simpleHaving(field, "!=", value);
    }

    /**
     * Special method to query the table by its primary key.
     *
     * If primary key is compound, only the columns that
     * belong to they key will be used for the query
     */
    public function havingIdIs(id)
    {
        return is_array(this->getPk()) ?
            this->having(this->getPkValue(id), null) :
            this->having(this->getPk(), id);
    }

    /**
     * Add a HAVING ... LIKE clause to your query.
     */
    public function havingLike(field, value=null)
    {
        return this->simpleHaving(field, "LIKE", value);
    }

    /**
     * Add where HAVING ... NOT LIKE clause to your query.
     */
    public function havingNotLike(field, value=null)
    {
        return this->simpleHaving(field, "NOT LIKE", value);
    }

    /**
     * Add a HAVING ... > clause to your query
     */
    public function havingGt(field, value=null)
    {
        return this->simpleHaving(field, ">", value);
    }

    /**
     * Add a HAVING ... < clause to your query
     */
    public function havingLt(field, value=null)
    {
        return this->simpleHaving(field, "<", value);
    }

    /**
     * Add a HAVING ... >= clause to your query
     */
    public function havingGte(field, value=null)
    {
        return this->simpleHaving(field, ">=", value);
    }

    /**
     * Add a HAVING ... <= clause to your query
     */
    public function havingLte(field, value=null)
    {
        return this->simpleHaving(field, "<=", value);
    }

    /**
     * Add a HAVING ... IN clause to your query
     */
    public function havingIn(field, values=null)
    {
        return this->_add_having_placeholder(field, "IN", values);
    }

    /**
     * Add a HAVING ... NOT IN clause to your query
     */
    public function havingNotIn(field, values=null)
    {
        return this->_add_having_placeholder(field, "NOT IN", values);
    }

    /**
     * Add a HAVING column IS NULL clause to your query
     */
    public function havingNull(field)
    {
        return this->_add_having_no_value(field, "IS NULL");
    }

    /**
     * Add a HAVING column IS NOT NULL clause to your query
     */
    public function havingNotNull(field)
    {
        return this->_add_having_no_value(field, "IS NOT NULL");
    }

    /**
     * Add a raw HAVING clause to the query. The clause should
     * contain question mark placeholders, which will be bound
     * to the parameters supplied in the second argument.
     */
    public function havingRaw(clause, parameters=[])
    {
        return this->_add_having(clause, parameters);
    }

    /**
     * Add a LIMIT to the query
     */
    public function limit(limit,offset=null) -> <Db>
    {
        let this->_limit = limit;
        if (typeof offset == "null") {
            return this;
        } else {
            return this->offset(offset);
        }
    }

    /**
     * Add an OFFSET to the query
     */
    public function offset(offset) -> <Db>
    {
        let this->_offset = offset;
        return this;
    }

    /**
     * 返回数组开关
     * 供绑定模型后返回多条记录使用
     *
     * <code>
     * User::where('1')->asArray()->select();
     * </code>
     *
     * @access public
     */
    public function asArray()-><Db>
    {
        let this->_as_array = true;
        return this;
    }

    /**
     * 获取一条记录并返回
     *
     * <code>
     * Db::name('user')->find(6);//Find by primary key value
     * Db::name('user')->where('uid',6)->find();
     * </code>
     *
     * @access public
     * @param integer|null
     * @return mixd
     */
    public function find(id=null)
    {
        var rows;
        string fun = "fetch";
        if (typeof id != "null") {
            this->whereIdIs(id);
        }
        this->limit(1);
        if this->_entity == null {
            let rows = this->run();
            if empty rows {
                return false;
            }
            return rows[0];
        }else{
            let rows = this->runForModel();
            if rows->rowCount() > 0 {
                return rows->{fun}(\PDO::FETCH_CLASS, this->_entity);
            } else {
                return false;
            }
        }
    }

    /**
     * 获取多条记录
     *
     * 执行此方法后，无法再进行链式调用
     *
     *<cdoe>
     *$users = Db::name('user')->select();
     *print_r($users);
     *</code>
     * @access public
     * @return array
     */
    public function select()
    {
        if this->_entity == null {
            return this->run();
        }else{
            return this->runForModel();
        }
    }

    /**
     * 执行COUNT查询
     *
     *<code>
     *Db::name('user')->count();
     *Db::name('user')->count('DISTINCT gid');
     *</code>
     *
     * @access public
     * @param string
     */
    public function count(column = "*")
    {
        return this->aggregate("COUNT", column);
    }

    /**
     * 执行MAX查询，获取字段最大值
     *
     *<code>
     *Db::name('user')->max('amount');
     *</code>
     *
     * @access public
     * @param string
     */
    public function max(column)
    {
        return this->aggregate("MAX", column);
    }

    /**
     * 执行MIN查询，获取字段最小值
     *
     *<code>
     *Db::name('user')->min('amount');
     *</code>
     *
     * @access public
     * @param string
     */
    public function min(column)
    {
        return this->aggregate("MIN", column);
    }

    /**
     * 执行AVG查询，获取字段平均值
     *
     *<code>
     *Db::name('logs')->avg('fee');
     *</code>
     *
     * @access public
     * @param string
     */
    public function avg(column)
    {
        return this->aggregate("AVG", column);
    }

    /**
     * 执行SUM查询，获取一列的和
     *
     *<code>
     *Db::name('logs')->sum('fee');
     *</code>
     *
     * @access public
     * @param string
     */
    public function sum(column)
    {
        return this->aggregate("SUM", column);
    }

    /**
     * 向数据表插入数据
     *
     *<code>
     *Db::name('news')->insert([
     *    'title' => 'title',
     *    'content' => 'content'
     *]);
     *</code>
     */
    public function insert(array! data)
    {
        if empty data {
            throw "Data can't empty";
        }
        var sql;
        let sql =  this->_build_insert(data);
        return self::_execute(sql, array_values(data), this->_name);
    }

    /**
     * 向数据表插入数据并返回插入的主键
     *
     *<code>
     *$newsid = Db::name('news')->insertGetId([
     *    'title' => 'title',
     *    'content' => 'content'
     *]);
     *</code>
     */
    public function insertGetId(array! data)
    {
        var sql,result,db;
        if empty data {
            throw "Data can't empty";
        }
        let sql =  this->_build_insert(data);
        let result = self::_execute(sql, array_values(data), this->_name);
        let db = self::getDb(this->_name);
        return result ? db->lastInsertId() : false;
    }

    /**
     * 更新数据表
     *
     *<code>
     *Db::name('news')->where('newsid',5)->update([
     *    'title' => 'title',
     *    'content' => 'content'
     *]);
     *</code>
     */
    public function update(array! data)
    {
        if empty data {
            throw "Data can't empty";
        }
        var sql,values;
        let sql =  this->_build_update(data);
        let values = array_merge(array_values(data),this->_values);
        return self::_execute(sql, values , this->_name);
    }

    /**
     * 从数据表删除数据
     *
     *<code>
     *Db::name('news')->where('newsid',5)->delete());
     *</code>
     */
    public function delete()
    {
        var query;
        let query = this->_join_if_not_empty(" ", [
            "DELETE FROM",
            this->quoteId(this->_table_name),
            this->_build_where()
        ]);
        return self::_execute(query, this->_values, this->_name);
    }

    /**
     * 开始执行事物
     *
     *<code>
     *Db::beginTransaction();
     *Db::beginTransaction('pdoName');//哪个pdo链接上执行
     *</code>
     */
    public static function beginTransaction(string! name = "default")
    {
        self::getDb(name)->beginTransaction();
    }

    /**
     * 提交事物
     *
     *<code>
     *Db::commit();
     *Db::commit('pdoName');//哪个pdo链接上提交
     *</code>
     */
    public static function commit(string! name = "default")
    {
        self::getDb(name)->commit();
    }

    /**
     * 回滚事务
     *
     *<code>
     *Db::rollBack();
     *Db::rollBack('pdoName');//哪个pdo链接上回滚
     *</code>
     */
    public static function rollBack(string! name = "default")
    {
        self::getDb(name)->rollBack();
    }

    /**
     * 事务封装
     *
     *<code>
     *Db::transaction([
     *   'DELETE FROM `logs` WHERE `typeid`=6 ',
     *   'UPDATE `counts` SET `num`=1 WHERE `typeid`=6'
     *], 'pdoName');
     *</code>
     */
    public static function transaction(array! sqls,string! name = "default")
    {
        var sql,db,e;
        let db = self::getDb(name);
        try {
            self::beginTransaction(name);
            for sql in sqls {
                db->exec(sql);
            }
            self::commit(name);
        } catch \PDOException,e {
            self::rollBack(name);
            die(e->getMessage());
        }
    }

    /**
     * 使用配置链接到数据库
     *
     * @access protected
     * @param string $name Which connection to use
     */
    protected static function connect(string! name = "default") -> void
    {
        if !isset self::_db[name] ||
            !is_object(self::_db[name]) {
            self::initConfig(name);
            var db,e;
            try {
                let db = new \PDO(
                    self::_config[name]["dsn"],
                    self::_config[name]["username"],
                    self::_config[name]["password"],
                    self::_config[name]["options"]
                );
                db->setAttribute(\PDO::ATTR_ERRMODE, self::_config[name]["error_mode"]);
                self::setDb(db, name);
            } catch \PDOException,e {
                die(e->getMessage());
            }
        }
    }

   /**
    * 初始化配置
    *
    * @access protected
    * @param string $name Which connection to use
    */
    protected static function initConfig(string! name) -> void
    {
        var config;
        if !isset self::_config[name] {
            let self::_config[name] = self::_default_config;
            let config = Config::get("db");
            if !empty config && typeof config == "array" {
                Db::init(config);
            }
        }
    }

    /**
     * 设置字段和表名的转移字符
     *
     * @access protected
     * @param string $name Which connection to use
     */
    protected static function setQuote(string! name) -> void
    {
        if is_null(self::_config[name]["quote"]) {
            let self::_config[name]["quote"] =
                self::detectQuoteChar(name);
        }
    }

    /**
     * 设置查询条数限制(Limit in mysql,TOP in MSSql)
     * 如果通过 Db::config("limit_style", "top"),进行了设置，那么本函数将不起作用
     *
     * @access public
     * @param string $name Which connection to use
     */
    protected static function setLimitStyle(string! name) -> void
    {
        if is_null(self::_config[name]["limit_style"]) {
            let self::_config[name]["limit_style"] =
                self::getLimitStyle(name);
        }
    }

    private static function getPdoDriver(string! name)->string
    {
        return (string) self::getDb(name)->getAttribute(\PDO::ATTR_DRIVER_NAME);
    }

    /**
     * 探测转义符号
     *
     * @access protected
     * @param string $name Which connection to use
     * @return string
     */
    protected static function detectQuoteChar(string! name)
    {
        string driver;
        let driver = (string) self::getPdoDriver(name);
        switch driver {
            case "pgsql":
            case "sqlsrv":
            case "dblib":
            case "mssql":
            case "sybase":
            case "firebird":
                return "\"";
            case "mysql":
            case "sqlite":
            case "sqlite2":
            default:
                return "`";
        }
    }

    /**
     * 返回LIMIT形式
     *
     * @access protected
     * @param string $name Which connection to use
     * @return string Limit clause style keyword/constant
     */
    protected static function getLimitStyle(string! name)->string
    {
        var driver;
        string drivers = "_sqlsrv_dblib_mssql_";
        let driver = self::getPdoDriver(name);
        return drivers->index("_".driver."_") ? "top" : "limit";
    }

   /**
    * 内部执行SQL的方法
    *
    * @access protected
    * @param string $query
    * @param array $parameters An array of parameters to be bound in to the query
    * @param string $name Which connection to use
    * @return bool Response of PDOStatement::execute()
    */
    protected static function _execute(query, parameters = [], name = "default")
    {
        //uncomment to debug
        //print_r(func_get_args());
        var statement,time,key,param,type,result,k,e;
        let statement = self::getDb(name)->prepare(query);
        let self::_last_statement = statement;
        let time = microtime(true);
        for key,param in parameters {
            if (typeof param == "null") {
                let type = \PDO::PARAM_NULL;
            } elseif (typeof param == "boolean") {
                let type = \PDO::PARAM_BOOL;
            } elseif (typeof param == "integer") {
                let type = \PDO::PARAM_INT;
            } else {
                let type = \PDO::PARAM_STR;
            }
            if (typeof key == "integer") {
                let k = key + 1;
                statement->bindValue(k, param, type);
            }else{
                statement->bindValue(key, param, type);
            }
        }
        try{
            let result = statement->execute();
        } catch \PDOException,e {
            die(e->getMessage());
        }
        //statement->debugDumpParams();
        self::_log_query(query, parameters, name, (microtime(true)-time));
        return result;
    }

    /**
     * 记录查询日志
     *
     * @access public
     * @param string $query
     * @param array $parameters 参数绑定
     * @param string $name Which connection to use
     * @param float $query_time Query time
     * @return bool
     */
    protected static function _log_query(query, parameters, name, query_time)
    {
        var key,val,bound_query;
        if !(self::_config[name]["logging"]) {
            return false;
        }
        if !isset self::_query_log[name] {
            let self::_query_log[name] = [];
        }
        if empty parameters {
            let bound_query = query;
        } else {
            let parameters = array_map([self::getDb(name), "quote"], parameters);
            if array_values(parameters) === parameters {
                let query = str_replace("%", "%%", query);
                if false !== strpos(query, "\"") || false !== strpos(query, "\"") {
                    let query = Helper::str_replace_outside_quotes("?", "%s", query);
                } else {
                    let query = str_replace("?", "%s", query);
                }
                let bound_query = vsprintf(query, parameters);
            } else {
                for key,val in parameters {
                    let query = str_replace(key, val, query);
                }
                let bound_query = query;
            }
        }
        let self::_last_query = bound_query;
        let self::_query_log[name][] = "[".query_time."] ".bound_query;

        if is_callable(self::_config[name]["logger"]) {
            call_user_func_array(self::_config[name]["logger"],[bound_query, query_time]);
        }
        return true;
    }


    /**
     * 执行常用统计函数
     *
     * @access protected
     * @param string $sql_function The aggregate function to call eg. MIN, COUNT, etc
     * @param string $column The column to execute the aggregate query against
     * @return int
     */
    protected function aggregate(func, column)
    {
        var alias,fields,result,v,return_value = 0;
        let alias = strtolower(func);
        let func  = strtoupper(func);
        if "*" != column {
            let column = this->quoteId(column);
        }
        let fields = this->_fields;
        let this->_fields = [];
        this->fieldExpr(func."(".column.")", alias);
        let result = this->find();
        let this->_fields = fields;
        if result !== false {
            let v = result[alias];
            if !empty v {
                if !is_numeric(v) {
                    let return_value = result->{alias};
                }elseif (int) v == (float) v {
                    let return_value = (int) v;
                } else {
                    let return_value = (float) v;
                }
            }
        }
        return return_value;
    }

    /**
     * Internal method to add an unquoted expression to the set
     * of columns returned by the SELECT query. The second optional
     * argument is the alias to return the expression as.
     */
    protected function _add_result_column(expr, alias=null)
    {
        if (typeof alias != "null") {
            let expr .= " AS " . this->quoteId(alias);
        }

        if !empty this->_using_default_fields {
            let this->_fields = [expr];
            let this->_using_default_fields = false;
        } else {
            let this->_fields[] = expr;
        }
        return this;
    }

    /**
     * Add a column to the list of columns returned by the SELECT
     * query. This defaults to "*". The second optional argument is
     * the alias to return the column as.
     */
    protected function field(string! column, alias=null)
    {
        let column = this->quoteId(column);
        return this->_add_result_column(column, alias);
    }

    /**
     * 查询表达式字段
     * @access protected
     */
    protected function fieldExpr(string! expr, alias=null)
    {
        return this->_add_result_column(expr, alias);
    }

    /**
     * 清理单个字段
     * @access protected
     */
    protected function trimField(string! field)->string
    {
        return (string) trim(field," \t\n\r\0\x0B`'\"[]");
    }

    /**
     * 内部方法向查询增加链接
     *
     * The join_operator should be one of INNER, LEFT OUTER, CROSS etc - this
     * will be prepended to JOIN.
     *
     * The table should be the name of the table to join to.
     *
     * The constraint may be either a string or an array with three elements. If it
     * is a string, it will be compiled into the query as-is, with no escaping. The
     * recommended way to supply the constraint is as an array with three elements:
     *
     * first_column, operator, second_column
     *
     * Example: array("user.id", "=", "profile.user_id")
     *
     * will compile to
     *
     * ON `user`.`id` = `profile`.`user_id`
     *
     * The final (optional) argument specifies an alias for the joined table.
     * @access protected
     */
    protected function _add_join_source(join_operator, table, constraint, table_alias=null)
    {
        var first_column,operator,second_column,prefix;
        let join_operator = trim(join_operator." JOIN");
        let prefix = this->getConfig("prefix");
        let prefix = (typeof prefix == "string") ? prefix : "";
        let table  = this->quoteId(prefix.table);

        // Add table alias if present
        if table_alias != null {
            let table_alias = this->quoteId(table_alias);
            let table .= " ".table_alias;
        }
        // Build the constraint
        if (typeof constraint == "array") {
            let first_column  = this->quoteId(constraint[0]);
            let operator      = this->quoteId(constraint[1]);
            let second_column = this->quoteId(constraint[2]);
            let constraint    = first_column." ".operator." ".second_column;
        }
        let this->_join_sources[] = join_operator." ".table." ON ".constraint;
        return this;
    }

    /**
     * Internal method to add a HAVING condition to the query
     */
    protected function _add_having(fragment, values=[])
    {
        return this->_add_condition("having", fragment, values);
    }

    /**
     * Internal method to add a HAVING condition to the query
     */
    protected function simpleHaving(field, separator, value)
    {
        return this->_add_simple_condition("having", field, separator, value);
    }

    /**
     * Internal method to add a HAVING clause with multiple values (like IN and NOT IN)
     */
    protected function _add_having_placeholder(field, separator, values)
    {
        var data,key,val,column,placeholders;
        if (typeof field != "array") {
            let data = [field : values];
        } else {
            let data = field;
        }
        for key,val in data {
            let column = this->quoteId(key);
            let placeholders = this->_create_placeholders(val);
            this->_add_having(column." ".separator." (".placeholders.")", val);
        }
        return this;
    }

    /**
     * Internal method to add a HAVING clause with no parameters(like IS NULL and IS NOT NULL)
     */
    protected function _add_having_no_value(field, operator)
    {
        var conditions,column;
        let conditions = (typeof field=="array") ? field : [field];
        for column in conditions {
            let column = this->quoteId(column);
            this->_add_having(column." ".operator);
        }
        return this;
    }

    /**
     * Internal method to add a WHERE condition to the query
     */
    protected function _add_where(fragment, values=[])
    {
        return this->_add_condition("where", fragment, values);
    }

    /**
     * Internal method to add a WHERE condition to the query
     */
    protected function simpleWhere(field, separator, value)
    {
        return this->_add_simple_condition("where", field, separator, value);
    }

    /**
     * Add a WHERE clause with multiple values (like IN and NOT IN)
     */
    protected function _add_where_placeholder(field, separator, values)
    {
        var data,key,val,placeholders,column;
        if (typeof field != "array") {
            let data = [field:values];
        } else {
            let data = field;
        }
        for key,val in data {
            let column = this->quoteId(key);
            let placeholders = this->_create_placeholders(val);
            this->_add_where(column." ".separator." (".placeholders.")", val);
        }
        return this;
    }

    /**
     * Add a WHERE clause with no parameters(like IS NULL and IS NOT NULL)
     */
    protected function _add_where_no_value(field, operator)
    {
        var conditions,column;
        let conditions = (typeof field=="array") ? field : [field];
        for column in conditions {
            let column = this->quoteId(column);
            this->_add_where(column." ".operator);
        }
        return this;
    }

    /**
     * Internal method to add a HAVING or WHERE condition to the query
     */
    protected function _add_condition(type, fragment, values=[])
    {
        var temp;
        let temp = (typeof values == "array") ? values : [values];
        if type == "where" {
            let this->_where_conditions[]=[
                0 : fragment,
                1 : temp
            ];
        } elseif type == "having" {
            let this->_having_conditions[]=[
                0 : fragment,
                1 : temp
            ];
        }
        return this;
    }

    /**
     * 内部方法处理where条件和having条件
     */
    protected function _add_simple_condition(type, field, separator, value)
    {
        array multiple;
        var key,val,table;
        let multiple = (typeof field == "array") ? field : [field : value];
        for key,val in multiple {
            if count(this->_join_sources) > 0 && strpos(key, ".") === false {
                let table = this->_table_name;
                if ( typeof this->_table_alias != "null") {
                    let table = this->_table_alias;
                }
                let key = table.".".key;
            }
            let key = this->quoteId(key);
            this->_add_condition(type, key." ".separator." ?", val);
        }
        return this;
    }

    /**
     * 创建占位符
     */
    protected function _create_placeholders(fields)
    {
        array db_fields = [];
        var key,value;
        if !empty fields {
            for key,value in fields {
                if isset this->_expr_fields[key] {
                    let db_fields[] = value;
                } else {
                    let db_fields[] = "?";
                }
            }
            return db_fields->join(", ");
        }
    }

    /**
     * Helper method that filters a column/value array returning only those
     * columns that belong to a compound primary key.
     *
     * If the key contains a column that does not exist in the given array,
     * a null value will be returned for it.
     */
    protected function getPkValue(value)
    {
        array filtered = [];
        var key;
        for key in this->getPk() {
            let filtered[key] = isset value[key] ? value[key] : null;
        }
        return filtered;
    }

   /**
     * Helper method that filters an array containing compound column/value
     * arrays.
     */
    protected function getPkValues(values)
    {
        array filtered = [];
        var value;
        for value in values {
            let filtered[] = this->getPkValue(value);
        }
        return filtered;
    }

    /**
     * 内部排序辅助方法
     */
    protected function _add_order_by(field, ordering) -> <Db>
    {
        let field = this->quoteId(field);
        let this->_order_by[] = field." ".ordering;
        return this;
    }

    /**
     * 组装SELECT
     * @access protected
     */
    protected function _build_select()
    {
        // If the query is raw, just set the $this->_values to be
        // the raw query parameters and return the raw query
        if !empty this->_is_raw_query {
            let this->_values = this->_raw_parameters;
            return this->_raw_query;
        }

        // Build and return the full SELECT statement by concatenating
        // the results of calling each separate builder method.
        return this->_join_if_not_empty(" ", [
            this->_build_select_start(),
            this->_build_join(),
            this->_build_where(),
            this->_build_group_by(),
            this->_build_having(),
            this->_build_order_by(),
            this->_build_limit(),
            this->_build_offset()
        ]);
    }

    /**
     * Build the start of the SELECT statement
     */
    protected function _build_select_start()
    {
        var fragment = "SELECT ",columns;
        let columns  = implode(", ", this->_fields);
        if !is_null(this->_limit) &&
            self::_config[this->_name]["limit_style"] === "top" {
            let fragment .= "TOP ".this->_limit." ";
        }
        if !empty this->_distinct {
            let columns = "DISTINCT " . columns;
        }
        let fragment .= columns." FROM " . this->quoteId(this->_table_name);
        if !is_null(this->_table_alias) {
            let fragment .= " " . this->quoteId(this->_table_alias);
        }
        return fragment;
    }

    /**
     * Build the JOIN sources
     */
    protected function _build_join()
    {
        if count(this->_join_sources) === 0 {
            return "";
        }
        return join(" ", this->_join_sources);
    }

    /**
     * Build the WHERE clause(s)
     */
    protected function _build_where()
    {
        return this->_build_conditions("where");
    }

    /**
     * Build the HAVING clause(s)
     */
    protected function _build_having()
    {
        return this->_build_conditions("having");
    }

    /**
     * Build GROUP BY
     */
    protected function _build_group_by()
    {
        if count(this->_group_by) === 0 {
            return "";
        }
        return "GROUP BY " . join(", ", this->_group_by);
    }

    /**
     * Build a WHERE or HAVING clause
     * @param string $type
     * @return string
     */
    protected function _build_conditions(type)->string
    {
        var condition;
        array conditions = [];
        if type == "where" {
            if count(this->_where_conditions) === 0 {
                return "";
            }
            for condition in this->_where_conditions {
                let conditions[] = condition[0];
                let this->_values = array_merge(this->_values, condition[1]);
            }
            return strtoupper(type) . " " . implode(" AND ", conditions);
        } elseif type == "having" {
            if count(this->_having_conditions) === 0 {
                return "";
            }
            for condition in this->_having_conditions {
                let conditions[] = condition[0];
                let this->_values = array_merge(this->_values, condition[1]);
            }
            return strtoupper(type) . " " . implode(" AND ", conditions);
        }
        return "";
    }

    /**
     * Build ORDER BY
     */
    protected function _build_order_by()->string
    {
        if count(this->_order_by) === 0 {
            return "";
        }
        return "ORDER BY " . implode(", ", this->_order_by);
    }

    /**
     * Build LIMIT
     */
    protected function _build_limit()->string
    {
        string fragment = "";
        if !is_null(this->_limit) &&
            self::_config[this->_name]["limit_style"] == "limit" {
            if self::getPdoDriver($this->_name) == "firebird" {
                let fragment = "ROWS";
            } else {
                let fragment = "LIMIT";
            }
            let fragment .= " ".this->_limit;
        }
        return fragment;
    }

    /**
     * Build OFFSET
     */
    protected function _build_offset() -> string
    {
        string clause = "OFFSET";
        if (typeof this->_offset != "null") {
            if self::getPdoDriver(this->_name) == "firebird" {
                let clause = "TO";
            }
            return clause." " . this->_offset;
        }
        return "";
    }

    /**
     * Wrapper around PHP"s join function which
     * only adds the pieces if they are not empty.
     */
    protected function _join_if_not_empty(glue, pieces)
    {
        array rs = [];
        var piece;
        for piece in pieces {
            if (typeof piece == "string") {
                let piece = trim(piece);
            }
            if !empty piece {
                let rs[] = piece;
            }
        }
        return implode(glue, rs);
    }

    /**
     * Quote a string that is used as an identifier
     * (table names, column names etc). This method can
     * also deal with dot-separated identifiers eg table.column
     */
    protected function quoteOne(identifier)
    {
        var parts;
        let parts = explode(".", identifier);
        let parts = array_map([this, "quoteIdPart"], parts);
        return implode(".", parts);
    }

    /**
     * Quote a string that is used as an identifier
     * (table names, column names etc) or an array containing
     * multiple identifiers. This method can also deal with
     * dot-separated identifiers eg table.column
     */
    public function quoteId(identifier)
    {
        var result;
        if (typeof identifier == "array")  {
            let result = array_map([this, "quoteOne"], identifier);
            return implode(", ", result);
        } else {
            return this->quoteOne(identifier);
        }
    }

    /**
     * This method performs the actual quoting of a single
     * part of an identifier, using the identifier quote
     * character specified in the config (or autodetected).
     */
    public function quoteIdPart(part)->string
    {
        string quote;
        if part === "*" {
            return part;
        }
        let quote = (string) self::_config[this->_name]["quote"];
        return quote.str_replace(quote, quote.quote, part).quote;
    }

    /**
     * Execute the SELECT query that has been built up by chaining methods
     * on this class. Return an array of rows as associative arrays.
     */
    protected function run()
    {
        var query,statement,rows,row;
        string fun = "fetch";
        let query = this->_build_select();
        self::_execute(query, this->_values, this->_name);
        let statement = self::getLastStatement();
        let rows = [];
        loop {
            let row = statement->{fun}(\PDO::FETCH_ASSOC);
            if empty row {
                break;
            }
            let rows[]=row;
        }
        let this->_values = [];
        let this->_fields = ["*"];
        let this->_using_default_fields = true;
        return rows;
    }

    /**
     * Execute the SELECT query that has been built up by chaining methods
     * on this class. Return an array of rows as associative arrays.
     */
    protected function runForModel() -> <\PDOStatement>|array
    {
        var query,statement,row,result;
        string fun = "fetch";
        let query = this->_build_select();
        self::_execute(query, this->_values, this->_name);
        let statement = self::getLastStatement();
        statement->setFetchMode(\PDO::FETCH_CLASS, this->_entity);
        let this->_values = [];
        let this->_fields = ["*"];
        let this->_using_default_fields = true;
        let this->_entity = null;
        if this->_as_array {
            let this->_as_array = false;
            let result = [];
            loop {
                let row = statement->{fun}(\PDO::FETCH_ASSOC);
                if empty row {
                    break;
                }
                let result[]=row;
            }
            return result;
        } else {
            return statement;
        }
    }

    /**
     * Return the name of the column in the database table which contains
     * the primary key ID of the row.
     */
    protected function getPk()
    {
        if !is_null(this->_instance_pk) {
            return this->_instance_pk;
        }
        if isset self::_config[this->_name]["primary_map"][this->_table_name] {
            return self::_config[this->_name]["primary_map"][this->_table_name];
        }
        return self::_config[this->_name]["primary"];
    }

    /**
     * Build an UPDATE query
     */
    protected function _build_update(array! data)
    {
        array query = [];
        string table;
        var key,value,where;
        array fields = [];
        let table = (string) this->quoteId(this->_table_name);
        let query[] = "UPDATE ".table." SET";
        for key,value in data {
            if !isset this->_expr_fields[key] {
                let value = "?";
            }
            let key = this->quoteId(key);
            let fields[] = key." = ".value;
        }
        let query[] = implode(", ", fields);
        let where = this->_build_where();
        if empty where {
            throw "Update on NO WHERE conditions";
        }
        let query[]= where;
        return query->join(" ");
    }

    /**
     * Build an INSERT query
     */
    protected function _build_insert(array! data)->string
    {
        array query = [];
        var fields,holders;
        let query[] = "INSERT INTO";
        let query[] = this->quoteId(this->_table_name);
        let fields  = array_map([this, "quoteId"], array_keys(data));
        let query[] = "(" . implode(", ", fields) . ")";
        let query[] = "VALUES";
        let holders = this->_create_placeholders(data);
        let query[] = "(".holders.")";
        if self::getPdoDriver(this->_name) == "pgsql" {
            let query[] = "RETURNING " . this->quoteId(this->getPk());
        }
        return query->join(" ");
    }

}

namespace Aimo;
use Aimo\Db\Helper;
class Db 
{
    const CONDITION_FRAGMENT = 0;
    const CONDITION_VALUES = 1;
    const LIMIT_STYLE_TOP_N = "top";
    const LIMIT_STYLE_LIMIT = "limit";
    protected static _default_config = [
        "dsn" : "sqlite::memory:",
        "id_column" : "id",
        "id_column_overrides" : [],
        "error_mode" : \PDO::ERRMODE_EXCEPTION,
        "username" : null,
        "password" : null,
        "options" : null,
        "identifier_quote_character" : null,
        "limit_clause_style" : null,
        "logging" : false,
        "logger" : null,
        "caching" : false,
        "caching_auto_clear" : false
    ];
    protected static _config = [];
    protected static _db = [];
    protected static _last_query;
    protected static _query_log = [];
    protected static _query_cache = [];
    protected static _last_statement = null;
    /**
     * 链接名称
     */
    protected _name;
    protected _table_name;
    protected _table_alias = null;
    protected _values = [];
    protected _result_columns = ["*"];
    protected _using_default_result_columns = true;
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
    protected _instance_id_column = null;
    /**
     * "Private" constructor; shouldn"t be called directly.
     * Use the ORM::for_table factory method instead.
     */
    protected function __construct(string! table_name, data = [], name = "default")
    {
        let this->_table_name = table_name;
        let this->_data = data;
        let this->_name = name;
        self::_setup_db_config(name);
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
     * @param string $key
     * @param mixed $value
     * @param string $name 那个链接
     */
    public static function config(string! key, value = null, name = "default") 
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
        self::_setup_db_config(name);
        var k,v;
        for k,v in config {
            if isset self::_default_config[k] {
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
     * @param string $key
     * @param string $name Which connection to use
     */
    public static function getConfig(key = null, name = "default") 
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
     * @param string $table_name 表的全名
     * @param string $name Which connection to use
     * @return Db
     */
    public static function table(string! table_name, name = "default") -> <Db>
    {
        self::_setup_db(name);
        return new self(table_name, [], name);
    }

    /**
     * 基于数据表的虚拟模型进行数据访问
     *
     * <code>
     * Db::name('user')->find();
     * </code>
     *
     * @param string $table_name 不含前缀的表名 （前提是在config中设置了prefix参数）
     * @param string $name Which connection to use
     * @return Db
     */
    public static function name(string! table_name, name = "default") -> <Db>
    {
        var prefix;
        self::_setup_db(name);
        let prefix = self::getConfig("prefix");
        return new self(prefix.table_name, [], name);
    }

    /**
     * Set up the database connection used by the class
     *
     * @param string $name Which connection to use
     */
    protected static function _setup_db(string! name = "default") -> void
    {
        if !isset self::_db[name] ||
            !is_object(self::_db[name]) {
            self::_setup_db_config(name);
            var db;
            let db = new \PDO(
                self::_config[name]["dsn"],
                self::_config[name]["username"],
                self::_config[name]["password"],
                self::_config[name]["options"]
            );
            db->setAttribute(\PDO::ATTR_ERRMODE, self::_config[name]["error_mode"]);
            self::setDb(db, name);
        }
    }

   /**
    * Ensures configuration (multiple connections) is at least set to default.
    * @param string $name Which connection to use
    */
    protected static function _setup_db_config(string! name) -> void
    {
        if !isset self::_config[name] {
            let self::_config[name] = [];
        }
    }

    /**
     * Set the PDO object used by ORM to communicate with the database.
     * This is public in case the ORM should use a ready-instantiated
     * PDO object as its database connection. Accepts an optional string key
     * to identify the connection if multiple connections are used.
     * @param PDO $db
     * @param string $name Which connection to use
     */
    public static function setDb(<\PDO> db, name = "default") -> void
    {
        self::_setup_db_config(name);
        let self::_db[name] = db;
        if !is_null(self::_db[name]) {
            self::_setup_identifier_quote_character(name);
            self::_setup_limit_clause_style(name);
        }
    }

    /**
     * Delete all registered PDO objects in _db array.
     */
    public static function resetDb() -> void
    {
        let self::_db = [];
    }

    /**
     * Detect and initialise the character used to quote identifiers
     * (table names, column names etc). If this has been specified
     * manually using ORM::configure("identifier_quote_character", "some-char"),
     * this will do nothing.
     * @param string $name Which connection to use
     */
    protected static function _setup_identifier_quote_character(string! name) -> void
    {
        if is_null(self::_config[name]["identifier_quote_character"]) {
            let self::_config[name]["identifier_quote_character"] =
                self::_detect_identifier_quote_character(name);
        }
    }

    /**
     * Detect and initialise the limit clause style ("SELECT TOP 5" /
     * "... LIMIT 5"). If this has been specified manually using 
     * ORM::configure("limit_clause_style", "top"), this will do nothing.
     * @param string $name Which connection to use
     */
    protected static function _setup_limit_clause_style(string! name) -> void
    {
        if is_null(self::_config[name]["limit_clause_style"]) {
            let self::_config[name]["limit_clause_style"] =
                self::_detect_limit_clause_style(name);
        }
    }

    /**
     * Return the correct character used to quote identifiers (table
     * names, column names etc) by looking at the driver being used by PDO.
     *
     * @param string $name Which connection to use
     * @return string
     */
    protected static function _detect_identifier_quote_character(string! name)
    {
        switch self::getDb(name)->getAttribute(\PDO::ATTR_DRIVER_NAME) {
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
     * Returns a constant after determining the appropriate limit clause
     * style
     *
     * @param string $name Which connection to use
     * @return string Limit clause style keyword/constant
     */
    protected static function _detect_limit_clause_style(string! name)->string
    {
        var driver;
        string drivers = "_sqlsrv_dblib_mssql_";
        let driver = self::getDb(name)->getAttribute(\PDO::ATTR_DRIVER_NAME);
        return drivers->index("_".driver."_") ? Db::LIMIT_STYLE_TOP_N : Db::LIMIT_STYLE_LIMIT;
    }

    /**
     * Returns the PDO instance used by the the ORM to communicate with
     * the database. This can be called if any low-level DB access is
     * required outside the class. If multiple connections are used,
     * accepts an optional key name for the connection.
     *
     * @param string $name Which connection to use
     * @return PDO
     */
    public static function getDb(string! name = "default") -> <\PDO>
    {
        self::_setup_db(name); // required in case this is called before ORM is instantiated
        return self::_db[name];
    }

    /**
     * Executes a raw query as a wrapper for PDOStatement::execute.
     * Useful for queries that can"t be accomplished through ORM,
     * particularly those using engine-specific features.
     *
     * <code>
     * Db::query("SELECT `name`, AVG(`order`) FROM `customer` GROUP BY `name` HAVING AVG(`order`) > 10")
     * Db::query("INSERT OR REPLACE INTO `widget` (`id`, `name`) SELECT `id`, `name` FROM `other_table`")
     * </code>
     *
     * @param string $query The raw SQL query
     * @param array  $parameters Optional bound parameters
     * @param string $name Which connection to use
     * @return bool Success
     */
    public static function query(string! query, parameters = [], name = "default") 
    {
        self::_setup_db(name);
        return self::_execute(query, parameters, name);
    }

    /**
     * Returns the PDOStatement instance last used by any connection wrapped by the ORM.
     * Useful for access to PDOStatement::rowCount() or error information
     * @return PDOStatement
     */
    public static function getLastStatement() -> <\PDOStatement>
    {
        return self::_last_statement;
    }


    /**
     * 获取最后执行的一句SQL
     *
     * @return string
     */
    public function getLastSql()
    {
        return self::getLastQuery();
    }

   /**
    * Internal helper method for executing statments. Logs queries, and
    * stores statement object in ::_last_statment, accessible publicly
    * through ::getLastStatement()
    * @param string $query
    * @param array $parameters An array of parameters to be bound in to the query
    * @param string $name Which connection to use
    * @return bool Response of PDOStatement::execute()
    */
    protected static function _execute(query, parameters = [], name = "default") 
    {
        var statement,time,key,param,type,result,k;
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
        let result = statement->execute();
        //statement->debugDumpParams();
        self::_log_query(query, parameters, name, (microtime(true)-time));
        return result;
    }

    /**
     * Add a query to the internal query log. Only works if the
     * "logging" config option is set to true.
     *
     * This works by manually binding the parameters to the query - the
     * query isn"t executed like this (PDO normally passes the query and
     * parameters to the database which takes care of the binding) but
     * doing it this way makes the logged queries more readable.
     * @param string $query
     * @param array $parameters An array of parameters to be bound in to the query
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
            // Escape the parameters
            let parameters = array_map([self::getDb(name), "quote"], parameters);

            if array_values(parameters) === parameters {
                // ? placeholders
                // Avoid %format collision for vsprintf
                let query = str_replace("%", "%%", query);

                // Replace placeholders in the query for vsprintf
                if false !== strpos(query, "\"") || false !== strpos(query, "\"") {
                    let query = Helper::str_replace_outside_quotes("?", "%s", query);
                } else {
                    let query = str_replace("?", "%s", query);
                }

                // Replace the question marks in the query with the parameters
                let bound_query = vsprintf(query, parameters);
            } else {
                
                for key,val in parameters {
                    let query = str_replace(key, val, query);
                }
                let bound_query = query;
            }
        }
        let self::_last_query = bound_query;
        let self::_query_log[name][] = bound_query;
        
        if is_callable(self::_config[name]["logger"]) {
            call_user_func_array(self::_config[name]["logger"],[bound_query, query_time]);
        }
        
        return true;
    }

    /**
     * Get the last query executed. Only works if the
     * "logging" config option is set to true. Otherwise
     * this will return null. Returns last query from all connections if
     * no name is specified
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
        if (isset(self::_query_log[name])) {
            return self::_query_log[name];
        }
        return [];
    }

    /**
     * Get a list of the available connection names
     * @return array
     */
    public static function getConnectionNames() 
    {
        return array_keys(self::_db);
    }

    /**
     * 获取一条记录并返回数组
     * 
     * <code>
     * Db::name('user')->find(6);//Find by primary key value
     * Db::name('user')->where('uid',6)->find();
     * </code>
     */
    public function find(id=null) 
    {
        var rows;
        if (typeof id != "null") {
            this->whereIdIs(id);
        }
        this->limit(1);
        let rows = this->_run();
        if empty rows {
            return false;
        }
        return rows[0];
    }

    /**
     * Tell the ORM that you are expecting multiple results
     * from your query, and execute it. Will return an array
     * of instances of the ORM class, or an empty array if
     * no rows were returned.
     * @return array
     */
    public function select() 
    {
        return this->_find_many();
    }

    /**
     * Tell the ORM that you are expecting multiple results
     * from your query, and execute it. Will return an array
     * of instances of the ORM class, or an empty array if
     * no rows were returned.
     * @return array
     */
    protected function _find_many()
    {
        return this->_run();
    }

    /**
     * Tell the ORM that you are expecting multiple results
     * from your query, and execute it. Will return an array,
     * or an empty array if no rows were returned.
     *
     * <code>
     * $info = Db::table('table')->fields('id,name')->getArray();
     * var_dump($info);
     * </code>
     *
     * @return array
     */
    public function getArray() 
    {
        return this->_run(); 
    }

    /**
     * Tell the ORM that you wish to execute a COUNT query.
     * Will return an integer representing the number of
     * rows returned.
     */
    public function count(column = "*") 
    {
        return this->_call_aggregate_db_function("COUNT", column);
    }

    /**
     * Tell the ORM that you wish to execute a MAX query.
     * Will return the max value of the choosen column.
     */
    public function max(column)
    {
        return this->_call_aggregate_db_function("MAX", column);
    }

    /**
     * Tell the ORM that you wish to execute a MIN query.
     * Will return the min value of the choosen column.
     */
    public function min(column)
    {
        return this->_call_aggregate_db_function("MIN", column);
    }

    /**
     * Tell the ORM that you wish to execute a AVG query.
     * Will return the average value of the choosen column.
     */
    public function avg(column) 
    {
        return this->_call_aggregate_db_function("AVG", column);
    }

    /**
     * Tell the ORM that you wish to execute a SUM query.
     * Will return the sum of the choosen column.
     */
    public function sum(column)
    {
        return this->_call_aggregate_db_function("SUM", column);
    }

    /**
     * Execute an aggregate query on the current connection.
     * @param string $sql_function The aggregate function to call eg. MIN, COUNT, etc
     * @param string $column The column to execute the aggregate query against
     * @return int
     */
    protected function _call_aggregate_db_function(sql_function, column) 
    {
        var alias,result_columns,result,v,return_value = 0;
        let alias = strtolower(sql_function);
        let sql_function = strtoupper(sql_function);
        if "*" != column {
            let column = this->_quote_identifier(column);
        }
        let result_columns = this->_result_columns;
        let this->_result_columns = [];
        this->fieldExpr(sql_function."(".column.")", alias);
        let result = this->find();
        let this->_result_columns = result_columns;
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
     * This method can be called to hydrate (populate) this
     * instance of the class from an associative array of data.
     * This will usually be called only from inside the class,
     * but it"s public in case you need to call it directly.
     */
    public function data(data=[]) 
    {
        let this->_data = data;
        return this;
    }

    /**
     * Perform a raw query. The query can contain placeholders in
     * either named or question mark style. If placeholders are
     * used, the parameters should be an array of values which will
     * be bound to the placeholders in the query. If this method
     * is called, all other query building methods will be ignored.
     *
     * <code>
     * Db::table('users')->sql('SELECT * `users` WHERE `uid` = ?',[3])->select();
     * </code>
     */
    public function sql(query, parameters = []) 
    {
        let this->_is_raw_query = true;
        let this->_raw_query = query;
        let this->_raw_parameters = parameters;
        return this;
    }

    /**
     * Add an alias for the main table to be used in SELECT queries
     *
     * <code>
     * Db::table('user')->alias('u')->where('u.uid',3)->find();
     * </code>
     */
    public function alias(string! alias) -> <Query>
    {
        let this->_table_alias = alias;
        return this;
    }

    /**
     * Internal method to add an unquoted expression to the set
     * of columns returned by the SELECT query. The second optional
     * argument is the alias to return the expression as.
     */
    protected function _add_result_column(expr, alias=null) 
    {
        if !is_null(alias) {
            let expr .= " AS " . this->_quote_identifier(alias);
        }

        if !empty this->_using_default_result_columns {
            let this->_result_columns = [expr];
            let this->_using_default_result_columns = false;
        } else {
            let this->_result_columns[] = expr;
        }
        return this;
    }

    /**
     * Add a column to the list of columns returned by the SELECT
     * query. This defaults to "*". The second optional argument is
     * the alias to return the column as.
     */
    protected function field(column, alias=null)
    {
        let column = this->_quote_identifier(column);
        return this->_add_result_column(column, alias);
    }

    /**
     * Add an unquoted expression to the list of columns returned
     * by the SELECT query. The second optional argument is
     * the alias to return the column as.
     */
    protected function fieldExpr(expr, alias=null)
    {
        return this->_add_result_column(expr, alias);
    }

    protected function trimField(string! field)
    {
        return trim(field," \t\n\r\0\x0B`'\"[]");
    }

    /**
     * Add columns to the list of columns returned by the SELECT
     * query. This defaults to "*". Many columns can be supplied
     * as either an array or as a list of parameters to the method.
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
     * //When due to use SQL Function may be contain "," syntax will be cause sql error;
     * Db::table('user')->field('uid,CONCAT(roleid,"_",departmentid) as rel');
     * </code>
     * @return <Query>
     */
    public function fields() -> <Query>
    {
        var columns,alias,column,fields,aliass,field,parts;
        let columns = func_get_args();
        if !empty columns {
            //let columns = this->_normalise_select_many_columns(columns);
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
     * Take a column specification for the select many methods and convert it
     * into a normalised array of columns and aliases.
     * 
     * It is designed to turn the following styles into a normalised array:
     * 
     * array(array("alias" => "column", "column2", "alias2" => "column3"), "column4", "column5"))
     * 
     * @param array $columns
     * @return array
     */
    protected function _normalise_select_many_columns(columns)->array 
    {
        var column,key,value;
        array result = [];
        for column in columns {
            if (typeof column == "array") {
                for key,value in column {
                    if !is_numeric(key) {
                        let result[key] = value;
                    } else {
                        let result[] = value;
                    }
                }
            } else {
                let result[]=column;
            }
        }
        return result;
    }

    /**
     * Add a DISTINCT keyword before the list of columns in the SELECT query
     */
    public function distinct()-><Query>
    {
        let this->_distinct = true;
        return this;
    }

    /**
     * Internal method to add a JOIN source to the query.
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
     */
    protected function _add_join_source(join_operator, table, constraint, table_alias=null) 
    {
        var first_column,operator,second_column,prefix;
        let join_operator = trim(join_operator." JOIN");
        let prefix = this->getConfig("prefix");
        let prefix = typeof prefix == "string" ? prefix : "";
        let table  = this->_quote_identifier(prefix.table);

        // Add table alias if present
        if table_alias != null {
            let table_alias = this->_quote_identifier(table_alias);
            let table .= " ".table_alias;
        }
        // Build the constraint
        if (typeof constraint == "array") {
            let first_column  = this->_quote_identifier(constraint[0]);
            let operator      = this->_quote_identifier(constraint[1]);
            let second_column = this->_quote_identifier(constraint[2]);
            let constraint    = first_column." ".operator." ".second_column;
        }
        let this->_join_sources[] = join_operator." ".table." ON ".constraint;
        return this;
    }

    /**
     * Add a RAW JOIN source to the query
     */
    public function rawJoin(table, constraint, table_alias = null, parameters = []) 
    {
        var first_column,operator,second_column;
        if table_alias != null {
            let table_alias = this->_quote_identifier(table_alias);
            let table = table." ".table_alias;
        }

        let this->_values = array_merge(this->_values, parameters);

        if (typeof constraint == "array")  {
            let first_column  = this->_quote_identifier(constraint[0]);
            let operator      = this->_quote_identifier(constraint[1]);
            let second_column = this->_quote_identifier(constraint[2]);
            let constraint  = first_column." ".operator." ".second_column;
        }

        let this->_join_sources[] = table." ON ".constraint;
        return this;
    }

    /**
     * Add a simple JOIN source to the query
     */
    public function join(table, constraint,joinType="LEFT", table_alias=null) 
    {
        string types = "_LEFT_RIGHT_INNER_FULL_";
        let joinType = strtoupper(joinType);
        if types->index("_".joinType."_") {
            return this->_add_join_source(joinType, table, constraint, table_alias);
        }
        throw "Unsupported JOIN TYPE";
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
    protected function _add_simple_having(column_name, separator, value) 
    {
        return this->_add_simple_condition("having", column_name, separator, value);
    }

    /**
     * Internal method to add a HAVING clause with multiple values (like IN and NOT IN)
     */
    protected function _add_having_placeholder(column_name, separator, values) 
    {
        var data,key,val,column,placeholders;
        if (typeof column_name != "array") {
            let data = [column_name : values];
        } else {
            let data = column_name;
        }
        for key,val in data {
            let column = this->_quote_identifier(key);
            let placeholders = this->_create_placeholders(val);
            this->_add_having(column." ".separator." (".placeholders.")", val);    
        }
        return this;
    }

    /**
     * Internal method to add a HAVING clause with no parameters(like IS NULL and IS NOT NULL)
     */
    protected function _add_having_no_value(column_name, operator) 
    {
        var conditions,column;
        let conditions = (typeof column_name=="array") ? column_name : [column_name];
        for column in conditions {
            let column = this->_quote_identifier(column);
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
    protected function _add_simple_where(column_name, separator, value) 
    {
        return this->_add_simple_condition("where", column_name, separator, value);
    }

    /**
     * Add a WHERE clause with multiple values (like IN and NOT IN)
     */
    protected function _add_where_placeholder(column_name, separator, values)
    {
        var data,key,val,placeholders,column;
        if (typeof column_name != "array") {
            let data = [column_name:values];
        } else {
            let data = column_name;
        }
        for key,val in data {
            let column = this->_quote_identifier(key);
            let placeholders = this->_create_placeholders(val);
            this->_add_where(column." ".separator." (".placeholders.")", val);    
        }
        return this;
    }

    /**
     * Add a WHERE clause with no parameters(like IS NULL and IS NOT NULL)
     */
    protected function _add_where_no_value(column_name, operator)
    {
        var conditions,column;
        let conditions = (typeof column_name=="array") ? column_name : [column_name];
        for column in conditions {
            let column = this->_quote_identifier(column);
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
        if type == "where" {
            if (typeof values != "array")  {
                let temp = [values];
            }
            let this->_where_conditions[]=[
                self::CONDITION_FRAGMENT : fragment,
                self::CONDITION_VALUES : temp
            ];
        } elseif type == "having" {
            if (typeof values != "array")  {
                let temp = [values];
            }
            let this->_having_conditions[]=[
                self::CONDITION_FRAGMENT : fragment,
                self::CONDITION_VALUES : temp
            ];
        }
        return this;
    }

   /**
     * Helper method to compile a simple COLUMN SEPARATOR VALUE
     * style HAVING or WHERE condition into a string and value ready to
     * be passed to the _add_condition method. Avoids duplication
     * of the call to _quote_identifier
     *
     * If column_name is an associative array, it will add a condition for each column
     */
    protected function _add_simple_condition(type, column_name, separator, value) 
    {
        array multiple;
        var key,val,table;
        let multiple = (typeof column_name == "array") ? column_name : [column_name : value];
        for key,val in multiple {
            if count(this->_join_sources) > 0 && strpos(key, ".") === false {
                let table = this->_table_name;
                if ( typeof this->_table_alias != "null") {
                    let table = this->_table_alias;
                }
                let key = table.".".key;
            }
            let key = this->_quote_identifier(key);
            this->_add_condition(type, key." ".separator." ?", val);
        }
        return this;
    } 

    /**
     * Return a string containing the given number of question marks,
     * separated by commas. Eg "?, ?, ?"
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
    protected function _get_compound_id_column_values(value) 
    {
        array filtered = [];
        var key;
        for key in this->_get_id_column_name() {
            let filtered[key] = isset value[key] ? value[key] : null;
        }
        return filtered;
    }

   /**
     * Helper method that filters an array containing compound column/value
     * arrays.
     */
    protected function _get_compound_id_column_values_array(values) 
    {
        array filtered = [];
        var value;
        for value in values {
            let filtered[] = this->_get_compound_id_column_values(value);
        }
        return filtered;
    }

    /**
     * Add a WHERE column = value clause to your query. Each time
     * this is called in the chain, an additional WHERE will be
     * added, and these will be ANDed together when the final query
     * is built.
     *
     * If you use an array in $column_name, a new clause will be
     * added for each element. In this case, $value is ignored.
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
     */
    public function where(a,b=null,c=null) 
    {
        var k,v;
        string operators;
        if a!=null && b==null && c==null {
            if (typeof a=="string" ) {
                return this->whereRaw(a);
            } elseif (typeof a == "array") {
                for k,v in a {
                    if !is_numeric(k) {
                        if (typeof v=="array") {
                            if count(v) === 2 {
                                this->_add_simple_where(k,v[0],v[1]);
                            }
                        } else {
                            this->whereEqual(k,v);
                        }
                    }
                }
                return this;
            }
        } elseif a!=null && b!=null && c==null {
            if (typeof a == "array"){
                throw "Not support conditon defination";
            } elseif (typeof a == "string") {
                if (typeof b == "array") {
                    return this->whereRaw(a,b);
                }elseif is_int(b) || is_float(b) || (typeof b == "string") {
                    return this->whereEqual(a,b);
                }
            }
        } elseif a!=null && b!=null && c!=null {
            let operators = "_=_!=_>_<>_<_>=_<=_LIKE_NOT LIKE_like_not like_";
            if operators->index("_".b."_") {
                return this->_add_simple_where(a, b, c);
            }
            if strcasecmp(b,"in") === 0 {
                return this->_add_where_placeholder(a, "IN", c);
            }
            if strcasecmp(b,"not in") === 0 {
                return this->_add_where_placeholder(a, "NOT IN", c);
            }
        }
        trigger_error("where method execute failed", E_USER_NOTICE);
        return this;
    }

    /**
     * More explicitly named version of for the where() method.
     * Can be used if preferred.
     */
    public function whereEqual(column_name, value=null) 
    {
        return this->_add_simple_where(column_name, "=", value);
    }

    /**
     * Add a WHERE column != value clause to your query.
     */
    public function whereNotEqual(column_name, value=null) 
    {
        return this->_add_simple_where(column_name, "!=", value);
    }

    /**
     * Special method to query the table by its primary key
     *
     * If primary key is compound, only the columns that
     * belong to they key will be used for the query
     */
    public function whereIdIs(id) 
    {
        return is_array(this->_get_id_column_name()) ?
            this->where(this->_get_compound_id_column_values(id), null) :
            this->where(this->_get_id_column_name(), id);
    }

    /**
     * Allows adding a WHERE clause that matches any of the conditions
     * specified in the array. Each element in the associative array will
     * be a different condition, where the key will be the column name.
     *
     * By default, an equal operator will be used against all columns, but
     * it can be overriden for any or every column using the second parameter.
     *
     * Each condition will be ORed together when added to the final query.
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
                let query[] = this->_quote_identifier(key);
                let data[] = item;
                let query[] = op . " ?";
            }
        }
        let query[] = "))";
        return this->whereRaw(query->join(" "), data);
    }

    /**
     * Similar to where_id_is() but allowing multiple primary keys.
     *
     * If primary key is compound, only the columns that
     * belong to they key will be used for the query
     *
     * <code>
     * $data = Db::table('table')->whereIdIn(['uid'=>3,'tagid'=>5]);
     * </code>
     */
    public function whereIdIn(ids) 
    {
        return is_array(this->_get_id_column_name()) ?
            this->whereAnyIs(this->_get_compound_id_column_values_array(ids)) :
            this->whereIn(this->_get_id_column_name(), ids);
    }

    /**
     * Add a WHERE ... LIKE clause to your query.
     *
     * <code>
     * $data = Db::table('table')->whereLike('name','keyword%');
     * </code>
     */
    public function whereLike(column_name, value=null) 
    {
        return this->_add_simple_where(column_name, "LIKE", value);
    }

    /**
     * Add where WHERE ... NOT LIKE clause to your query.
     *
     * <code>
     * $data = Db::table('table')->whereNotLike('name','keyword%');
     * </code>
     */
    public function whereNotLike(column_name, value=null) 
    {
        return this->_add_simple_where(column_name, "NOT LIKE", value);
    }

    /**
     * Add a WHERE ... > clause to your query
     *
     * <code>
     * $data = Db::table('table')->whereGt('score',60);
     * </code>
     */
    public function whereGt(column_name, value=null) 
    {
        return this->_add_simple_where(column_name, ">", value);
    }

    /**
     * Add a WHERE ... < clause to your query
     *
     **<code>
     * $data = Db::table('table')->whereLt('score',60);
     * </code>
     */
    public function whereLt(column_name, value=null) 
    {
        return this->_add_simple_where(column_name, "<", value);
    }

    /**
     * Add a WHERE ... >= clause to your query
     *
     * <code>
     * $data = Db::table('table')->whereGte('score',60);
     * </code>
     */
    public function whereGte(column_name, value=null) 
    {
        return this->_add_simple_where(column_name, ">=", value);
    }

    /**
     * Add a WHERE ... <= clause to your query
     *
     * <code>
     * $data = Db::table('table')->whereLte('score',60);
     * </code>
     */
    public function whereLte(column_name, value=null) {
        return this->_add_simple_where(column_name, "<=", value);
    }

    /**
     * Add a WHERE ... IN clause to your query
     *
     * <code>
     * $data = Db::table('table')->whereIn('field',['a','b','c']);
     * </code>
     */
    public function whereIn(column_name, values) 
    {
        return this->_add_where_placeholder(column_name, "IN", values);
    }

    /**
     * Add a WHERE ... NOT IN clause to your query
     *
     * <code>
     * $data = Db::table('table')->whereNotIn('field',['a','b','c']);
     * </code>
     */
    public function whereNotIn(column_name, values) 
    {
        return this->_add_where_placeholder(column_name, "NOT IN", values);
    }

    /**
     * Add a WHERE column IS NULL clause to your query
     *
     * <code>
     * $data = Db::table('table')->whereIsNull('field');
     * </code>
     */
    public function whereIsNull(column_name) 
    {
        return this->_add_where_no_value(column_name, "IS NULL");
    }

    /**
     * Add a WHERE column IS NOT NULL clause to your query
     *
     * <code>
     * $data = Db::table('table')->whereNotNull('field');
     * </code>
     */
    public function whereNotNull(column_name) 
    {
        return this->_add_where_no_value(column_name, "IS NOT NULL");
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
     * Add a LIMIT to the query
     */
    public function limit(limit,offset=null) 
    {
        let this->_limit = limit;
        if is_null(offset) {
            return this;
        } else {
            return this->offset(offset);
        }
    }

    /**
     * Add an OFFSET to the query
     */
    public function offset(offset) 
    {
        let this->_offset = offset;
        return this;
    }

    /**
     * Add an ORDER BY clause to the query
     */
    protected function _add_order_by(column_name, ordering) 
    {
        let column_name = this->_quote_identifier(column_name);
        let this->_order_by[] = column_name." ".ordering;
        return this;
    }

    /**
     * Add an ORDER BY column DESC clause
     */
    public function orderByDesc(column_name) 
    {
        return this->_add_order_by(column_name, "DESC");
    }

    /**
     * Add an ORDER BY column ASC clause
     */
    public function orderByAsc(column_name) 
    {
        return this->_add_order_by(column_name, "ASC");
    }

    /**
     * Add an unquoted expression as an ORDER BY clause
     */
    public function orderByExpr(clause) 
    {
        let this->_order_by[] = clause;
        return this;
    }

    /**
     * Add a column to the list of columns to GROUP BY
     */
    public function groupBy(column_name) 
    {
        let column_name = this->_quote_identifier(column_name);
        let this->_group_by[] = column_name;
        return this;
    }

    /**
     * Add an unquoted expression to the list of columns to GROUP BY 
     */
    public function groupByExpr(expr) 
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
     * If you use an array in $column_name, a new clause will be
     * added for each element. In this case, $value is ignored.
     */
    public function having(column_name, value=null) 
    {
        return this->havingEqual(column_name, value);
    }

    /**
     * More explicitly named version of for the having() method.
     * Can be used if preferred.
     */
    public function havingEqual(column_name, value=null) 
    {
        return this->_add_simple_having(column_name, "=", value);
    }

    /**
     * Add a HAVING column != value clause to your query.
     */
    public function havingNotEqual(column_name, value=null) 
    {
        return this->_add_simple_having(column_name, "!=", value);
    }

    /**
     * Special method to query the table by its primary key.
     *
     * If primary key is compound, only the columns that
     * belong to they key will be used for the query
     */
    public function havingIdIs(id) 
    {
        return is_array(this->_get_id_column_name()) ?
            this->having(this->_get_compound_id_column_values(id), null) :
            this->having(this->_get_id_column_name(), id);
    }

    /**
     * Add a HAVING ... LIKE clause to your query.
     */
    public function havingLike(column_name, value=null) 
    {
        return this->_add_simple_having(column_name, "LIKE", value);
    }

    /**
     * Add where HAVING ... NOT LIKE clause to your query.
     */
    public function havingNotLike(column_name, value=null) 
    {
        return this->_add_simple_having(column_name, "NOT LIKE", value);
    }

    /**
     * Add a HAVING ... > clause to your query
     */
    public function havingGt(column_name, value=null) 
    {
        return this->_add_simple_having(column_name, ">", value);
    }

    /**
     * Add a HAVING ... < clause to your query
     */
    public function havingLt(column_name, value=null)
    {
        return this->_add_simple_having(column_name, "<", value);
    }

    /**
     * Add a HAVING ... >= clause to your query
     */
    public function havingGte(column_name, value=null)
    {
        return this->_add_simple_having(column_name, ">=", value);
    }

    /**
     * Add a HAVING ... <= clause to your query
     */
    public function havingLte(column_name, value=null)
    {
        return this->_add_simple_having(column_name, "<=", value);
    }

    /**
     * Add a HAVING ... IN clause to your query
     */
    public function havingIn(column_name, values=null) 
    {
        return this->_add_having_placeholder(column_name, "IN", values);
    }

    /**
     * Add a HAVING ... NOT IN clause to your query
     */
    public function havingNotIn(column_name, values=null)
    {
        return this->_add_having_placeholder(column_name, "NOT IN", values);
    }

    /**
     * Add a HAVING column IS NULL clause to your query
     */
    public function havingNull(column_name) 
    {
        return this->_add_having_no_value(column_name, "IS NULL");
    }

    /**
     * Add a HAVING column IS NOT NULL clause to your query
     */
    public function havingNotNull(column_name) 
    {
        return this->_add_having_no_value(column_name, "IS NOT NULL");
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
     * Build a SELECT statement based on the clauses that have
     * been passed to this instance by chaining method calls.
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
        var fragment = "SELECT ",result_columns;
        let result_columns = implode(", ", this->_result_columns);

        if !is_null(this->_limit) &&
            self::_config[this->_name]["limit_clause_style"] === Db::LIMIT_STYLE_TOP_N {
            let fragment .= "TOP ".this->_limit." ";
        }

        if !empty this->_distinct {
            let result_columns = "DISTINCT " . result_columns;
        }

        let fragment .= result_columns." FROM " . this->_quote_identifier(this->_table_name);

        if !is_null(this->_table_alias) {
            let fragment .= " " . this->_quote_identifier(this->_table_alias);
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
                let conditions[] = condition[self::CONDITION_FRAGMENT];
                let this->_values = array_merge(this->_values, condition[self::CONDITION_VALUES]);
            }
            return strtoupper(type) . " " . implode(" AND ", conditions);
        } elseif type == "having" {
            if count(this->_having_conditions) === 0 {
                return "";
            }
            for condition in this->_having_conditions {
                let conditions[] = condition[self::CONDITION_FRAGMENT];
                let this->_values = array_merge(this->_values, condition[self::CONDITION_VALUES]);
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
            self::_config[this->_name]["limit_clause_style"] == Db::LIMIT_STYLE_LIMIT {
            if self::getDb(this->_name)->getAttribute(\PDO::ATTR_DRIVER_NAME) == "firebird" {
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
        if !is_null(this->_offset) {
            if self::getDb(this->_name)->getAttribute(\PDO::ATTR_DRIVER_NAME) == "firebird" {
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
        array filtered_pieces = [];
        var piece;
        for piece in pieces {
            if (typeof piece == "string") {
                let piece = trim(piece);
            }
            if !empty piece {
                let filtered_pieces[] = piece;
            }
        }
        return implode(glue, filtered_pieces);
    }

    /**
     * Quote a string that is used as an identifier
     * (table names, column names etc). This method can
     * also deal with dot-separated identifiers eg table.column
     */
    protected function _quote_one_identifier(identifier) 
    {
        var parts;
        let parts = explode(".", identifier);
        let parts = array_map([this, "_quote_identifier_part"], parts);
        return implode(".", parts);
    }

    /**
     * Quote a string that is used as an identifier
     * (table names, column names etc) or an array containing
     * multiple identifiers. This method can also deal with
     * dot-separated identifiers eg table.column
     */
    protected function _quote_identifier(identifier) 
    {
        var result;
        if (typeof identifier == "array")  {
            let result = array_map([this, "_quote_one_identifier"], identifier);
            return implode(", ", result);
        } else {
            return this->_quote_one_identifier(identifier);
        }
    }

    /**
     * This method performs the actual quoting of a single
     * part of an identifier, using the identifier quote
     * character specified in the config (or autodetected).
     */
    protected function _quote_identifier_part(part)->string 
    {
        var quote_character;
        if part === "*" {
            return part;
        }
        let quote_character = self::_config[this->_name]["identifier_quote_character"];
        // double up any identifier quotes to escape them
        return quote_character .
               str_replace(quote_character,
                           quote_character . quote_character,
                           part
               ) . quote_character;
    }

    /**
     * Create a cache key for the given query and parameters.
     */
    protected static function _create_cache_key(query, parameters, table_name = null, name = "default") 
    {
        var parameter_string,key;
        if isset self::_config[name]["create_cache_key"] && 
            is_callable(self::_config[name]["create_cache_key"]) {
            return call_user_func_array(self::_config[name]["create_cache_key"], [query, parameters, table_name, name]);
        }
        let parameter_string = implode(",", parameters);
        let key = query . ":" . parameter_string;
        return sha1(key);
    }

    /**
     * Check the query cache for the given cache key. If a value
     * is cached for the key, return the value. Otherwise, return false.
     */
    protected static function _check_query_cache(cache_key, table_name = null, name = "default") 
    {
        if isset self::_config[name]["check_query_cache"] && 
            is_callable(self::_config[name]["check_query_cache"]) {
            return call_user_func_array(self::_config[name]["check_query_cache"], [cache_key, table_name, name]);
        } elseif isset self::_query_cache[name][cache_key]  {
            return self::_query_cache[name][cache_key];
        }
        return false;
    }

    /**
     * Clear the query cache
     */
    public static function clearCache(table_name = null, name = "default") 
    {
        let self::_query_cache = [];
        if isset self::_config[name]["clear_cache"] && 
        is_callable(self::_config[name]["clear_cache"]) {
            return call_user_func_array(self::_config[name]["clear_cache"], [table_name, name]);
        }
    }

    /**
     * Add the given value to the query cache.
     */
    protected static function _cache_query_result(cache_key, value, table_name = null, name = "default") 
    {
        if isset self::_config[name]["cache_query_result"] && 
            is_callable(self::_config[name]["cache_query_result"]) {
            return call_user_func_array(self::_config[name]["cache_query_result"], [cache_key, value,table_name, name]);
        } elseif !isset self::_query_cache[name] {
            let self::_query_cache[name] = [];
        }
        let self::_query_cache[name][cache_key] = value;
    }

    /**
     * Execute the SELECT query that has been built up by chaining methods
     * on this class. Return an array of rows as associative arrays.
     */
    protected function _run() 
    {
        var query,caching_enabled,cache_key,cached_result,statement,rows,row;
        string fun = "fetch";
        let query = this->_build_select();
        let caching_enabled = self::_config[this->_name]["caching"];

        if caching_enabled {
            let cache_key = self::_create_cache_key(query, this->_values, this->_table_name, this->_name);
            let cached_result = self::_check_query_cache(cache_key, this->_table_name, this->_name);
            if cached_result !== false {
                return cached_result;
            }
        }
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
        if caching_enabled {
            self::_cache_query_result(cache_key, rows, this->_table_name, this->_name);
        }
        // reset ORM after executing the query
        let this->_values = [];
        let this->_result_columns = ["*"];
        let this->_using_default_result_columns = true;
        return rows;
    }

    /**
     * Return the raw data wrapped by this ORM
     * instance as an associative array. Column
     * names may optionally be supplied as arguments,
     * if so, only those keys will be returned.
     */
    public function asArray() 
    {
        var args = func_get_args();
        if func_num_args() === 0 {
            return this->_data;
        }
        return array_intersect_key(this->_data, array_flip(args));
    }

    /**
     * Return the name of the column in the database table which contains
     * the primary key ID of the row.
     */
    protected function _get_id_column_name() 
    {
        if !is_null(this->_instance_id_column) {
            return this->_instance_id_column;
        }
        if isset self::_config[this->_name]["id_column_overrides"][this->_table_name] {
            return self::_config[this->_name]["id_column_overrides"][this->_table_name];
        }
        return self::_config[this->_name]["id_column"];
    }

    /**
     * Build an UPDATE query
     */
    protected function _build_update(array! data) 
    {
        array query = [];
        var table,key,value,where;
        array field_list = [];
        let table = this->_quote_identifier(this->_table_name);
        let query[] = "UPDATE ".table." SET";
        for key,value in data {
            if !isset this->_expr_fields[key] {
                let value = "?";
            }
            let key = this->_quote_identifier(key);
            let field_list[] = key." = ".value;
        }
        let query[] = implode(", ", field_list);
        let where = this->_build_where();
        if empty where {
            throw "Update on NO WHERE conditions";
        }
        let query[]= "WHERE ".where;
        return implode(" ", query);
    }

    /**
     * Build an INSERT query
     */
    protected function _build_insert(array! data) 
    {
        array query;
        var field_list,placeholders;
        let query[] = "INSERT INTO";
        let query[] = this->_quote_identifier(this->_table_name);
        let field_list = array_map([this, "_quote_identifier"], array_keys(data));
        let query[] = "(" . implode(", ", field_list) . ")";
        let query[] = "VALUES";
        let placeholders = this->_create_placeholders(data);
        let query[] = "(".placeholders.")";
        if self::getDb(this->_name)->getAttribute(\PDO::ATTR_DRIVER_NAME) == "pgsql" {
            let query[] = "RETURNING " . this->_quote_identifier(this->_get_id_column_name());
        }
        return implode(" ", query);
    }

    public function insert(array! data)
    {
        if empty data {
            throw "Data can't empty";
        }
        var sql;
        let sql =  this->_build_insert(data);
        return self::_execute(sql, array_values(data), this->_name);
    }

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

    public function update(array! data)
    {
        if empty data {
            throw "Data can't empty";
        }
        var sql;
        let sql =  this->_build_update(data);
        return self::_execute(sql, array_values(data), this->_name);
    }

    /**
     * Delete many records from the database
     */
    public function delete() 
    {
        var query;
        let query = this->_join_if_not_empty(" ", [
            "DELETE FROM",
            this->_quote_identifier(this->_table_name),
            this->_build_where()
        ]);
        return self::_execute(query, this->_values, this->_name);
    }
}
namespace Aimo\Db;
class Query implements \ArrayAccess {

    const CONDITION_FRAGMENT = 0;
    const CONDITION_VALUES = 1;

    const DEFAULT_CONNECTION = "default";

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
        "caching_auto_clear" : false,
        "return_result_sets" : false
    ];

    // Map of configuration settings
    protected static _config = [];

    // Map of database connections, instances of the PDO class
    protected static _db = [];

    // Last query run, only populated if logging is enabled
    protected static _last_query;

    // Log of all queries run, mapped by connection key, only populated if logging is enabled
    protected static _query_log = [];

    // Query cache, only used if query caching is enabled
    protected static _query_cache = [];

    // Reference to previously used PDOStatement object to enable low-level access, if needed
    protected static _last_statement = null;

    // --------------------------- //
    // --- INSTANCE PROPERTIES --- //
    // --------------------------- //

    // Key name of the connections in self::_db used by this instance
    protected _connection_name;

    // The name of the table the current ORM instance is associated with
    protected _table_name;

    // Alias for the table to be used in SELECT queries
    protected _table_alias = null;

    // Values to be bound to the query
    protected _values = [];

    // Columns to select in the result
    protected _result_columns = ["*"];

    // Are we using the default result column or have these been manually changed?
    protected _using_default_result_columns = true;

    // Join sources
    protected _join_sources = [];

    // Should the query include a DISTINCT keyword?
    protected _distinct = false;

    // Is this a raw query?
    protected _is_raw_query = false;

    // The raw query
    protected _raw_query = "";

    // The raw query parameters
    protected _raw_parameters = [];

    // Array of WHERE clauses
    protected _where_conditions = [];

    // LIMIT
    protected _limit = null;

    // OFFSET
    protected _offset = null;

    // ORDER BY
    protected _order_by = [];

    // GROUP BY
    protected _group_by = [];

    // HAVING
    protected _having_conditions = [];

    // The data for a hydrated instance of the class
    protected _data = [];

    // Fields that have been modified during the
    // lifetime of the object
    protected _dirty_fields = [];

    // Fields that are to be inserted in the DB raw
    protected _expr_fields = [];

    // Is this a new object (has create() been called)?
    protected _is_new = false;

    // Name of the column to use as the primary key for
    // this instance only. Overrides the config settings.
    protected _instance_id_column = null;

    // ---------------------- //
    // --- STATIC METHODS --- //
    // ---------------------- //

    /**
     * Pass configuration settings to the class
     *
     * As a shortcut, if the second argument
     * is omitted and the key is a string, the setting is
     * assumed to be the DSN string used by PDO to connect
     * to the database (often, this will be the only configuration
     * required to use Idiorm). If you have more than one setting
     * you wish to configure, another shortcut is to pass an array
     * of settings (and omit the second argument).
     * <code>
     * Query::configure('mysql:host=localhost;dbname=dbname');
     * Query::configure('username','username');
     * Query::configure('password','password');
     * Query::configure('options',[\PDO::MYSQL_ATTR_INIT_COMMAND => 'SET NAMES utf8']);
     * </code>
     * @param string $key
     * @param mixed $value
     * @param string $connection_name Which connection to use
     */
    public static function configure(key, value = null, connection_name = self::DEFAULT_CONNECTION) 
    {
        self::_setup_db_config(connection_name); //ensures at least default config is set
        if ( typeof key == "array" ) {
            // Shortcut: If only one array argument is passed,
            // assume it"s an array of configuration settings
            var conf_key,conf_value;
            for conf_key,conf_value in key {
                self::configure(conf_key, conf_value, connection_name);
            }
        } else {
            if (typeof value == "null") {
                // Shortcut: If only one string argument is passed, 
                // assume it"s a connection string
                let value = key;
                let key = "dsn";
            }
            let self::_config[connection_name][key] = value;
        }
    }

    public static function config(array! config)
    {
        self::configure("mysql:host=localhost;dbname=my_database");
        self::configure("username", "username");
        self::configure("password", "password");
        //self::configure("options", array(PDO::MYSQL_ATTR_INIT_COMMAND => "SET NAMES utf8"));
    }

    /**
     * Retrieve configuration options by key, or as whole array.
     *
     * <code>
     * //value
     * Query::getConfig('username');
     * //array
     * Query::getConfig('username');
     * </code>
     *
     * @param string $key
     * @param string $connection_name Which connection to use
     */
    public static function getConfig(key = null, connection_name = self::DEFAULT_CONNECTION) 
    {
        if !empty key {
            return self::_config[connection_name][key];
        } else {
            return self::_config[connection_name];
        }
    }

    /**
     * Delete all configs in _config array.
     *
     * <code>
     * Query::resetConfig();
     * </code>
     */
    public static function resetConfig()
    {
        let self::_config = [];
    }
    
    /**
     * Despite its slightly odd name, this is actually the factory
     * method used to acquire instances of the class. It is named
     * this way for the sake of a readable interface, As such,
     * this will normally be the first method called in a chain.
     *
     * <code>
     * Query::table('user')->find();
     * </code>
     *
     * @param string $table_name
     * @param string $connection_name Which connection to use
     * @return Query
     */
    public static function table(string! table_name, connection_name = self::DEFAULT_CONNECTION) 
    {
        self::_setup_db(connection_name);
        return new self(table_name, [], connection_name);
    }

    /**
     * Set up the database connection used by the class
     *
     * @param string $connection_name Which connection to use
     */
    protected static function _setup_db(connection_name = self::DEFAULT_CONNECTION) 
    {
        if !array_key_exists(connection_name, self::_db) ||
            !is_object(self::_db[connection_name]) {
            self::_setup_db_config(connection_name);
            var db;
            let db = new \PDO(
                self::_config[connection_name]["dsn"],
                self::_config[connection_name]["username"],
                self::_config[connection_name]["password"],
                self::_config[connection_name]["options"]
            );

            db->setAttribute(\PDO::ATTR_ERRMODE, self::_config[connection_name]["error_mode"]);
            self::setDb(db, connection_name);
        }
    }

   /**
    * Ensures configuration (multiple connections) is at least set to default.
    * @param string $connection_name Which connection to use
    */
    protected static function _setup_db_config(connection_name) 
    {
        
        if !array_key_exists(connection_name, self::_config) {
            let self::_config[connection_name] = self::_default_config;
        }
    }

    /**
     * Set the PDO object used by Idiorm to communicate with the database.
     * This is public in case the ORM should use a ready-instantiated
     * PDO object as its database connection. Accepts an optional string key
     * to identify the connection if multiple connections are used.
     * @param PDO $db
     * @param string $connection_name Which connection to use
     */
    public static function setDb(<\PDO> db, connection_name = self::DEFAULT_CONNECTION) 
    {
        self::_setup_db_config(connection_name);
        let self::_db[connection_name] = db;
        if !is_null(self::_db[connection_name]) {
            self::_setup_identifier_quote_character(connection_name);
            self::_setup_limit_clause_style(connection_name);
        }
    }

    /**
     * Delete all registered PDO objects in _db array.
     */
    public static function resetDb()
    {
        let self::_db = [];
    }

    /**
     * Detect and initialise the character used to quote identifiers
     * (table names, column names etc). If this has been specified
     * manually using ORM::configure("identifier_quote_character", "some-char"),
     * this will do nothing.
     * @param string $connection_name Which connection to use
     */
    protected static function _setup_identifier_quote_character(connection_name) 
    {
        if is_null(self::_config[connection_name]["identifier_quote_character"]) {
            let self::_config[connection_name]["identifier_quote_character"] =
                self::_detect_identifier_quote_character(connection_name);
        }
    }

    /**
     * Detect and initialise the limit clause style ("SELECT TOP 5" /
     * "... LIMIT 5"). If this has been specified manually using 
     * ORM::configure("limit_clause_style", "top"), this will do nothing.
     * @param string $connection_name Which connection to use
     */
    public static function _setup_limit_clause_style(connection_name) 
    {
        if is_null(self::_config[connection_name]["limit_clause_style"]) {
            let self::_config[connection_name]["limit_clause_style"] =
                self::_detect_limit_clause_style(connection_name);
        }
    }

    /**
     * Return the correct character used to quote identifiers (table
     * names, column names etc) by looking at the driver being used by PDO.
     *
     * @param string $connection_name Which connection to use
     * @return string
     */
    protected static function _detect_identifier_quote_character(connection_name)
    {
        switch self::getDb(connection_name)->getAttribute(\PDO::ATTR_DRIVER_NAME) {
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
     * @param string $connection_name Which connection to use
     * @return string Limit clause style keyword/constant
     */
    protected static function _detect_limit_clause_style(connection_name)->string
    {
        var driver;
        string drivers = "_sqlsrv_dblib_mssql_";
        let driver = self::getDb(connection_name)->getAttribute(\PDO::ATTR_DRIVER_NAME);
        return drivers->index("_".driver."_") ? Query::LIMIT_STYLE_TOP_N : Query::LIMIT_STYLE_LIMIT;
    }

    /**
     * Returns the PDO instance used by the the ORM to communicate with
     * the database. This can be called if any low-level DB access is
     * required outside the class. If multiple connections are used,
     * accepts an optional key name for the connection.
     *
     * @param string $connection_name Which connection to use
     * @return PDO
     */
    public static function getDb(connection_name = self::DEFAULT_CONNECTION) 
    {
        self::_setup_db(connection_name); // required in case this is called before Idiorm is instantiated
        return self::_db[connection_name];
    }

    /**
     * Executes a raw query as a wrapper for PDOStatement::execute.
     * Useful for queries that can"t be accomplished through Idiorm,
     * particularly those using engine-specific features.
     *
     * <code>
     * Query::query("SELECT `name`, AVG(`order`) FROM `customer` GROUP BY `name` HAVING AVG(`order`) > 10")
     * Query::query("INSERT OR REPLACE INTO `widget` (`id`, `name`) SELECT `id`, `name` FROM `other_table`")
     * </code>
     *
     * @param string $query The raw SQL query
     * @param array  $parameters Optional bound parameters
     * @param string $connection_name Which connection to use
     * @return bool Success
     */
    public static function query(string! query, parameters = [], connection_name = self::DEFAULT_CONNECTION) 
    {
        self::_setup_db(connection_name);
        return self::_execute(query, parameters, connection_name);
    }

    /**
     * Returns the PDOStatement instance last used by any connection wrapped by the ORM.
     * Useful for access to PDOStatement::rowCount() or error information
     * @return PDOStatement
     */
    public static function getLastStatement() 
    {
        return self::_last_statement;
    }

   /**
    * Internal helper method for executing statments. Logs queries, and
    * stores statement object in ::_last_statment, accessible publicly
    * through ::getLastStatement()
    * @param string $query
    * @param array $parameters An array of parameters to be bound in to the query
    * @param string $connection_name Which connection to use
    * @return bool Response of PDOStatement::execute()
    */
    protected static function _execute(query, parameters = [], connection_name = self::DEFAULT_CONNECTION) 
    {
        var statement,time,key,param,type,result;
        let statement = self::getDb(connection_name)->prepare(query);
        let self::_last_statement = statement;
        let time = microtime(true);
        for key,param in parameters {
            if is_null(param) {
                let type = \PDO::PARAM_NULL;
            } elseif is_bool(param) {
                let type = \PDO::PARAM_BOOL;
            } elseif is_int(param) {
                let type = \PDO::PARAM_INT;
            } else {
                let type = \PDO::PARAM_STR;
            }
            if is_int(key) {
                let key = key + 1;
            }
            statement->bindParam(key, param, type);
        }
        let result = statement->execute();
        self::_log_query(query, parameters, connection_name, (microtime(true)-time));
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
     * @param string $connection_name Which connection to use
     * @param float $query_time Query time
     * @return bool
     */
    protected static function _log_query(query, parameters, connection_name, query_time) 
    {
        var key,val,bound_query;
        if !(self::_config[connection_name]["logging"]) {
            return false;
        }
        if !isset self::_query_log[connection_name] {
            let self::_query_log[connection_name] = [];
        }
        if empty parameters {
            let bound_query = query;
        } else {
            // Escape the parameters
            let parameters = array_map([self::getDb(connection_name), "quote"], parameters);

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
        let self::_query_log[connection_name][] = bound_query;
        
        if is_callable(self::_config[connection_name]["logger"]) {
            call_user_func_array(self::_config[connection_name]["logger"],[bound_query, query_time]);
        }
        
        return true;
    }

    /**
     * Get the last query executed. Only works if the
     * "logging" config option is set to true. Otherwise
     * this will return null. Returns last query from all connections if
     * no connection_name is specified
     * @param null|string $connection_name Which connection to use
     * @return string
     */
    public static function getLastQuery(connection_name = null) 
    {
        if connection_name === null {
            return self::_last_query;
        }
        if !isset self::_query_log[connection_name] {
            return "";
        }

        return end(self::_query_log[connection_name]);
    }

    /**
     * Get an array containing all the queries run on a
     * specified connection up to now.
     * Only works if the "logging" config option is
     * set to true. Otherwise, returned array will be empty.
     * @param string $connection_name Which connection to use
     */
    public static function getQueryLog(connection_name = self::DEFAULT_CONNECTION)
    {
        if (isset(self::_query_log[connection_name])) {
            return self::_query_log[connection_name];
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

    // ------------------------ //
    // --- INSTANCE METHODS --- //
    // ------------------------ //

    /**
     * "Private" constructor; shouldn"t be called directly.
     * Use the ORM::for_table factory method instead.
     */
    protected function __construct(table_name, data = [], connection_name = self::DEFAULT_CONNECTION)
    {
        let this->_table_name = table_name;
        let this->_data = data;

        let this->_connection_name = connection_name;
        self::_setup_db_config(connection_name);
    }

    /**
     * Create a new, empty instance of the class. Used
     * to add a new row to your database. May optionally
     * be passed an associative array of data to populate
     * the instance. If so, all fields will be flagged as
     * dirty so all will be saved to the database when
     * save() is called.
     */
    public function create(data = null) {
        let this->_is_new = true;
        if !is_null(data) {
            return this->hydrate(data)->force_all_dirty();
        }
        return this;
    }

    /**
     * Specify the ID column to use for this instance or array of instances only.
     * This overrides the id_column and id_column_overrides settings.
     *
     * This is mostly useful for libraries built on top of Idiorm, and will
     * not normally be used in manually built queries. If you don"t know why
     * you would want to use this, you should probably just ignore it.
     */
    public function use_id_column(id_column)
    {
        let this->_instance_id_column = id_column;
        return this;
    }

    /**
     * Create an ORM instance from the given row (an associative
     * array of data fetched from the database)
     */
    protected function _create_instance_from_row(row) 
    {
        var instance;
        let instance = self::table(this->_table_name, this->_connection_name);
        instance->use_id_column(this->_instance_id_column);
        instance->hydrate(row);
        return instance;
    }

    /**
     * Tell the ORM that you are expecting a single result
     * back from your query, and execute it. Will return
     * a single instance of the ORM class, or false if no
     * rows were returned.
     * As a shortcut, you may supply an ID as a parameter
     * to this method. This will perform a primary key
     * lookup on the table.
     */
    public function find(id=null) 
    {
        var rows;
        if !is_null(id) {
            this->whereIdIs(id);
        }
        this->limit(1);
        let rows = this->_run();
        if empty rows {
            return false;
        }
        return this->_create_instance_from_row(rows[0]);
    }

    /**
     * Tell the ORM that you are expecting multiple results
     * from your query, and execute it. Will return an array
     * of instances of the ORM class, or an empty array if
     * no rows were returned.
     * @return array| ResultSet
     */
    public function select() 
    {
        if(self::_config[this->_connection_name]["return_result_sets"]) {
            return this->find_result_set();
        }
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
        var rows;
        let rows = this->_run();
        return array_map([this, "_create_instance_from_row"], rows);
    }

    /**
     * Tell the ORM that you are expecting multiple results
     * from your query, and execute it. Will return a result set object
     * containing instances of the ORM class.
     * @return ResultSet
     */
    public function find_result_set() 
    {
        return new ResultSet(this->_find_many());
    }

    /**
     * Tell the ORM that you are expecting multiple results
     * from your query, and execute it. Will return an array,
     * or an empty array if no rows were returned.
     *
     * <code>
     * $info = Query::table('table')->fields('id,name')->getArray();
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
    public function max(column)  {
        return this->_call_aggregate_db_function("MAX", column);
    }

    /**
     * Tell the ORM that you wish to execute a MIN query.
     * Will return the min value of the choosen column.
     */
    public function min(column)  {
        return this->_call_aggregate_db_function("MIN", column);
    }

    /**
     * Tell the ORM that you wish to execute a AVG query.
     * Will return the average value of the choosen column.
     */
    public function avg(column)  {
        return this->_call_aggregate_db_function("AVG", column);
    }

    /**
     * Tell the ORM that you wish to execute a SUM query.
     * Will return the sum of the choosen column.
     */
    public function sum(column)  {
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
        var alias,result_columns,result,return_value = 0;
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
        if result !== false && isset result->{alias} {
            if !is_numeric(result->{alias}) {
                let return_value = result->{alias};
            }elseif (int) result->{alias} == (float) result->{alias} {
                let return_value = (int) result->{alias};
            } else {
                let return_value = (float) result->{alias};
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
    public function hydrate(data=[]) {
        let this->_data = data;
        return this;
    }

    /**
     * Force the ORM to flag all the fields in the $data array
     * as "dirty" and therefore update them when save() is called.
     */
    public function force_all_dirty() {
        let this->_dirty_fields = this->_data;
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
     * Query::table('users')->sql('SELECT * `users` WHERE `uid` = ?',[3])->select();
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
     * Query::table('user')->alias('u')->where('u.uid',3)->find();
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
     * Counts the number of columns that belong to the primary
     * key and their value is null.
     */
    public function count_null_id_columns() 
    {
        if is_array(this->_get_id_column_name()) {
            return count(array_filter(this->id(), "is_null"));
        } else {
            return is_null(this->id()) ? 1 : 0;
        }
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
     * Query::table('user')->fields('uid,username,password')->...;
     * Query::table('user')->fields('uid,username,password as hash')->...;
     * Query::table('logs')->fields('uid,COUNT(*) as count')->...;
     * Query::table('user')->fields('uid,username',['amount'=>'SUM(`fee`)'])->...;
     * //Wrong example
     * //When due to use SQL Function may be contain "," syntax will be cause sql error;
     * Query::table('user')->field('uid,CONCAT(roleid,"_",departmentid) as rel');
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
        var first_column,operator,second_column;
        let join_operator = trim(join_operator." JOIN");
        let table = this->_quote_identifier(table);

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
    public function join(table, constraint, table_alias=null) 
    {
        return this->_add_join_source("LEFT JOIN", table, constraint, table_alias);
    }

    /**
     * Add an INNER JOIN souce to the query
     */
    public function innerJoin(table, constraint, table_alias=null) 
    {
        return this->_add_join_source("INNER", table, constraint, table_alias);
    }

    /**
     * Add a LEFT OUTER JOIN souce to the query
     */
    public function leftOuterJoin(table, constraint, table_alias=null) 
    {
        return this->_add_join_source("LEFT OUTER", table, constraint, table_alias);
    }

    /**
     * Add an RIGHT OUTER JOIN souce to the query
     */
    public function rightOuterJoin(table, constraint, table_alias=null) 
    {
        return this->_add_join_source("RIGHT OUTER", table, constraint, table_alias);
    }

    /**
     * Add an FULL OUTER JOIN souce to the query
     */
    public function fullOuterJoin(table, constraint, table_alias=null) 
    {
        return this->_add_join_source("FULL OUTER", table, constraint, table_alias);
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
    public function _add_having_placeholder(column_name, separator, values) 
    {
        var data,result,key,val,column,placeholders;
        if (typeof column_name != "array") {
            let data = [column_name : values];
        } else {
            let data = column_name;
        }
        let result = this;
        for key,val in data {
            let column = result->_quote_identifier(key);
            let placeholders = result->_create_placeholders(val);
            let result = result->_add_having(column." ".separator." (".placeholders.")", val);    
        }
        return result;
    }

    /**
     * Internal method to add a HAVING clause with no parameters(like IS NULL and IS NOT NULL)
     */
    public function _add_having_no_value(column_name, operator) 
    {
        var conditions,result,column;
        let conditions = (typeof column_name=="array") ? column_name : [column_name];
        let result = this;
        for column in conditions {
            let column = this->_quote_identifier(column);
            let result = result->_add_having(column." ".operator);
        }
        return result;
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
        var data,key,val,placeholders,result,column;
        if (typeof column_name != "array") {
            let data = [column_name:values];
        } else {
            let data = column_name;
        }
        let result = this;
        for key,val in data {
            let column = result->_quote_identifier(key);
            let placeholders = result->_create_placeholders(val);
            let result = result->_add_where(column." ".separator." (".placeholders.")", val);    
        }
        return result;
    }

    /**
     * Add a WHERE clause with no parameters(like IS NULL and IS NOT NULL)
     */
    protected function _add_where_no_value(column_name, operator)
    {
        var conditions,result,column;
        let conditions = (typeof column_name=="array") ? column_name : [column_name];
        let result = this;
        for column in conditions {
            let column = this->_quote_identifier(column);
            let result = result->_add_where(column." ".operator);
        }
        return result;
    }

    /**
     * Internal method to add a HAVING or WHERE condition to the query
     */
    protected function _add_condition(type, fragment, values=[]) 
    {
        string conditions_class_property_name;
        let conditions_class_property_name = "_".type."_conditions";
        if (typeof values != "array")  {
            let values = [values];
        }
        array_push(this->{conditions_class_property_name}, [
            self::CONDITION_FRAGMENT : fragment,
            self::CONDITION_VALUES : values
        ]);
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
        var result,key,val,table;
        let multiple = (typeof column_name == "array") ? column_name : [column_name : value];
        let result   = this;
        for key,val in multiple {
            if count(result->_join_sources) > 0 && strpos(key, ".") === false {
                let table = result->_table_name;
                if !is_null(result->_table_alias) {
                    let table = result->_table_alias;
                }

                let key = table.".".key;
            }
            let key = result->_quote_identifier(key);
            let result = result->_add_condition(type, key." ".separator." ?", val);
        }
        return result;
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
                if array_key_exists(key, this->_expr_fields) {
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
     * Query::table('user')->where('uid=3')->find();
     * Query::table('user')->where('uid=?',[3])->find();
     * //>,<,!=,<>,>=,<=
     * Query::table('user')->where('uid','=',3)->find();
     * //IS NULL
     * Query::table('user')->where('lastlogin',NULL)->find();
     * //Default login is AND
     * Query::table('user')->where([
     *     'groupid' => 2,
     *     'role' => ['<>','editor'],
     *     'name' => ['LIKE', 'test%'],
     * ])->select();
     * </code>
     */
    public function where() 
    {
        var params,count,k,v,result;
        string operators;
        let params = func_get_args();
        let count = count(params);
        if count === 1 {
            if (typeof params[0]=="string" ) {
                return this->whereRaw(params[0]);
            } elseif (typeof params[0]=="array") {
                let result = this;
                for k,v in params[0] {
                    if !is_numeric(k) {
                        if (typeof v=="array") {
                            if count(v) === 2 {
                                let result = result->where(k,v[0],v[1]);
                            }
                        } else {
                            let result = result->whereEqual(k,v);
                        }
                    }
                }
                return result;
            }
        } elseif count === 2 {
            if (typeof params[0] == "array"){
                throw "Not support conditon defination";
            } elseif (typeof params[0] == "string") {
                if params[1] === null {
                    return this->whereIsNull(params[0]);
                }
                if (typeof params[1] == "array") {
                    return this->whereRaw(params[0],params[1]);
                }
            }
        } elseif count === 3 {
            let operators = "_=_!=_>_<>_<_>=_<=_LIKE_NOT LIKE_like_not like_";
            if operators->index("_".params[1]."_") {
                return this->_add_simple_where(params[0], params[1], params[2]);
            }
            if strcasecmp(params[1],"in") === 0 {
                return this->_add_where_placeholder(params[0], "IN", params[2]);
            }
            if strcasecmp(params[1],"not in") === 0 {
                return this->_add_where_placeholder(params[0], "NOT IN", params[2]);
            }
        }
        trigger_error("where method execute failed", E_USER_NOTICE);
        return this;
    }

    /**
     * More explicitly named version of for the where() method.
     * Can be used if preferred.
     */
    protected function whereEqual(column_name, value=null) 
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
    public function whereIdIs(id) {
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
     */
    public function whereIdIn(ids) {
        return is_array(this->_get_id_column_name()) ?
            this->whereAnyIs(this->_get_compound_id_column_values_array(ids)) :
            this->whereIn(this->_get_id_column_name(), ids);
    }

    /**
     * Add a WHERE ... LIKE clause to your query.
     */
    public function whereLike(column_name, value=null) {
        return this->_add_simple_where(column_name, "LIKE", value);
    }

    /**
     * Add where WHERE ... NOT LIKE clause to your query.
     */
    public function whereNotLike(column_name, value=null) {
        return this->_add_simple_where(column_name, "NOT LIKE", value);
    }

    /**
     * Add a WHERE ... > clause to your query
     */
    public function whereGt(column_name, value=null) {
        return this->_add_simple_where(column_name, ">", value);
    }

    /**
     * Add a WHERE ... < clause to your query
     */
    public function whereLt(column_name, value=null) {
        return this->_add_simple_where(column_name, "<", value);
    }

    /**
     * Add a WHERE ... >= clause to your query
     */
    public function whereGte(column_name, value=null) {
        return this->_add_simple_where(column_name, ">=", value);
    }

    /**
     * Add a WHERE ... <= clause to your query
     */
    public function whereLte(column_name, value=null) {
        return this->_add_simple_where(column_name, "<=", value);
    }

    /**
     * Add a WHERE ... IN clause to your query
     */
    public function whereIn(column_name, values) {
        return this->_add_where_placeholder(column_name, "IN", values);
    }

    /**
     * Add a WHERE ... NOT IN clause to your query
     */
    public function whereNotIn(column_name, values) {
        return this->_add_where_placeholder(column_name, "NOT IN", values);
    }

    /**
     * Add a WHERE column IS NULL clause to your query
     */
    public function whereIsNull(column_name) {
        return this->_add_where_no_value(column_name, "IS NULL");
    }

    /**
     * Add a WHERE column IS NOT NULL clause to your query
     */
    public function whereNotNull(column_name) {
        return this->_add_where_no_value(column_name, "IS NOT NULL");
    }

    /**
     * Add a raw WHERE clause to the query. The clause should
     * contain question mark placeholders, which will be bound
     * to the parameters supplied in the second argument.
     */
    public function whereRaw(clause, parameters=[]) {
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
    public function order_by_desc(column_name) 
    {
        return this->_add_order_by(column_name, "DESC");
    }

    /**
     * Add an ORDER BY column ASC clause
     */
    public function order_by_asc(column_name) 
    {
        return this->_add_order_by(column_name, "ASC");
    }

    /**
     * Add an unquoted expression as an ORDER BY clause
     */
    public function order_by_expr(clause) 
    {
        let this->_order_by[] = clause;
        return this;
    }

    /**
     * Add a column to the list of columns to GROUP BY
     */
    public function group_by(column_name) 
    {
        let column_name = this->_quote_identifier(column_name);
        let this->_group_by[] = column_name;
        return this;
    }

    /**
     * Add an unquoted expression to the list of columns to GROUP BY 
     */
    public function group_by_expr(expr) 
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
        return this->having_equal(column_name, value);
    }

    /**
     * More explicitly named version of for the having() method.
     * Can be used if preferred.
     */
    public function having_equal(column_name, value=null) 
    {
        return this->_add_simple_having(column_name, "=", value);
    }

    /**
     * Add a HAVING column != value clause to your query.
     */
    public function having_not_equal(column_name, value=null) 
    {
        return this->_add_simple_having(column_name, "!=", value);
    }

    /**
     * Special method to query the table by its primary key.
     *
     * If primary key is compound, only the columns that
     * belong to they key will be used for the query
     */
    public function having_id_is(id) 
    {
        return is_array(this->_get_id_column_name()) ?
            this->having(this->_get_compound_id_column_values(id), null) :
            this->having(this->_get_id_column_name(), id);
    }

    /**
     * Add a HAVING ... LIKE clause to your query.
     */
    public function having_like(column_name, value=null) 
    {
        return this->_add_simple_having(column_name, "LIKE", value);
    }

    /**
     * Add where HAVING ... NOT LIKE clause to your query.
     */
    public function having_not_like(column_name, value=null) {
        return this->_add_simple_having(column_name, "NOT LIKE", value);
    }

    /**
     * Add a HAVING ... > clause to your query
     */
    public function having_gt(column_name, value=null) {
        return this->_add_simple_having(column_name, ">", value);
    }

    /**
     * Add a HAVING ... < clause to your query
     */
    public function having_lt(column_name, value=null) {
        return this->_add_simple_having(column_name, "<", value);
    }

    /**
     * Add a HAVING ... >= clause to your query
     */
    public function having_gte(column_name, value=null) {
        return this->_add_simple_having(column_name, ">=", value);
    }

    /**
     * Add a HAVING ... <= clause to your query
     */
    public function having_lte(column_name, value=null) {
        return this->_add_simple_having(column_name, "<=", value);
    }

    /**
     * Add a HAVING ... IN clause to your query
     */
    public function having_in(column_name, values=null) {
        return this->_add_having_placeholder(column_name, "IN", values);
    }

    /**
     * Add a HAVING ... NOT IN clause to your query
     */
    public function having_not_in(column_name, values=null) {
        return this->_add_having_placeholder(column_name, "NOT IN", values);
    }

    /**
     * Add a HAVING column IS NULL clause to your query
     */
    public function having_null(column_name) {
        return this->_add_having_no_value(column_name, "IS NULL");
    }

    /**
     * Add a HAVING column IS NOT NULL clause to your query
     */
    public function having_not_null(column_name) {
        return this->_add_having_no_value(column_name, "IS NOT NULL");
    }

    /**
     * Add a raw HAVING clause to the query. The clause should
     * contain question mark placeholders, which will be bound
     * to the parameters supplied in the second argument.
     */
    public function having_raw(clause, parameters=[]) {
        return this->_add_having(clause, parameters);
    }

    /**
     * Build a SELECT statement based on the clauses that have
     * been passed to this instance by chaining method calls.
     */
    protected function _build_select() {
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
        let result_columns = join(", ", this->_result_columns);

        if !is_null(this->_limit) &&
            self::_config[this->_connection_name]["limit_clause_style"] === Query::LIMIT_STYLE_TOP_N {
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
    protected function _build_where() {
        return this->_build_conditions("where");
    }

    /**
     * Build the HAVING clause(s)
     */
    protected function _build_having() {
        return this->_build_conditions("having");
    }

    /**
     * Build GROUP BY
     */
    protected function _build_group_by() {
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
        string name;
        var condition;
        array conditions = [];
        let name = "_".type."_conditions";
        if count(this->{name}) === 0 {
            return "";
        }
        for condition in this->{name} {
            let conditions[] = condition[self::CONDITION_FRAGMENT];
            let this->_values = array_merge(this->_values, condition[self::CONDITION_VALUES]);
        }
        return strtoupper(type) . " " . implode(" AND ", conditions);
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
            self::_config[this->_connection_name]["limit_clause_style"] == Query::LIMIT_STYLE_LIMIT {
            if self::getDb(this->_connection_name)->getAttribute(\PDO::ATTR_DRIVER_NAME) == "firebird" {
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
            if self::getDb(this->_connection_name)->getAttribute(\PDO::ATTR_DRIVER_NAME) == "firebird" {
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
    protected function _quote_one_identifier(identifier) {
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
    protected function _quote_identifier(identifier) {
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
        let quote_character = self::_config[this->_connection_name]["identifier_quote_character"];
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
    protected static function _create_cache_key(query, parameters, table_name = null, connection_name = self::DEFAULT_CONNECTION) {
        var parameter_string,key;
        if isset self::_config[connection_name]["create_cache_key"] && 
            is_callable(self::_config[connection_name]["create_cache_key"]) {
            return call_user_func_array(self::_config[connection_name]["create_cache_key"], [query, parameters, table_name, connection_name]);
        }
        let parameter_string = implode(",", parameters);
        let key = query . ":" . parameter_string;
        return sha1(key);
    }

    /**
     * Check the query cache for the given cache key. If a value
     * is cached for the key, return the value. Otherwise, return false.
     */
    protected static function _check_query_cache(cache_key, table_name = null, connection_name = self::DEFAULT_CONNECTION) {
        if isset self::_config[connection_name]["check_query_cache"] && 
            is_callable(self::_config[connection_name]["check_query_cache"]) {
            return call_user_func_array(self::_config[connection_name]["check_query_cache"], [cache_key, table_name, connection_name]);
        } elseif isset self::_query_cache[connection_name][cache_key]  {
            return self::_query_cache[connection_name][cache_key];
        }
        return false;
    }

    /**
     * Clear the query cache
     */
    public static function clear_cache(table_name = null, connection_name = self::DEFAULT_CONNECTION) {
        let self::_query_cache = [];
        if isset self::_config[connection_name]["clear_cache"] && 
        is_callable(self::_config[connection_name]["clear_cache"]) {
            return call_user_func_array(self::_config[connection_name]["clear_cache"], [table_name, connection_name]);
        }
    }

    /**
     * Add the given value to the query cache.
     */
    protected static function _cache_query_result(cache_key, value, table_name = null, connection_name = self::DEFAULT_CONNECTION) 
    {
        if isset self::_config[connection_name]["cache_query_result"] && 
            is_callable(self::_config[connection_name]["cache_query_result"]) {
            return call_user_func_array(self::_config[connection_name]["cache_query_result"], [cache_key, value,table_name, connection_name]);
        } elseif !isset self::_query_cache[connection_name] {
            let self::_query_cache[connection_name] = [];
        }
        let self::_query_cache[connection_name][cache_key] = value;
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
        let caching_enabled = self::_config[this->_connection_name]["caching"];

        if caching_enabled {
            let cache_key = self::_create_cache_key(query, this->_values, this->_table_name, this->_connection_name);
            let cached_result = self::_check_query_cache(cache_key, this->_table_name, this->_connection_name);
            if cached_result !== false {
                return cached_result;
            }
        }

        self::_execute(query, this->_values, this->_connection_name);
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
            self::_cache_query_result(cache_key, rows, this->_table_name, this->_connection_name);
        }
        // reset Idiorm after executing the query
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
     * Return the value of a property of this object (database row)
     * or null if not present.
     *
     * If a column-names array is passed, it will return a associative array
     * with the value of each column or null if it is not present.
     */
    public function get(key) 
    {
        array result = [];
        var column;
        if typeof key == "array" {
            for column in key {
                let result[column] = isset this->_data[column] ? this->_data[column] : null;
            }
            return result;
        } else {
            return isset this->_data[key] ? this->_data[key] : null;
        }
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
        if isset self::_config[this->_connection_name]["id_column_overrides"][this->_table_name] {
            return self::_config[this->_connection_name]["id_column_overrides"][this->_table_name];
        }
        return self::_config[this->_connection_name]["id_column"];
    }

    /**
     * Get the primary key ID of this object.
     */
    public function id(disallow_null = false) 
    {
        var id,id_part;
        let id = this->get(this->_get_id_column_name());
        if disallow_null {
            if (typeof id == "array") {
                for id_part in id {
                    if id_part === null {
                        throw "Primary key ID contains null value(s)";
                    }
                }
                
            } elseif id === null {
                throw "Primary key ID missing from row or is null";
            }
        }
        return id;
    }

    /**
     * Set a property to a particular value on this object.
     * To set multiple properties at once, pass an associative array
     * as the first parameter and leave out the second parameter.
     * Flags the properties as "dirty" so they will be saved to the
     * database when save() is called.
     */
    public function set(key, value = null) 
    {
        return this->_set_orm_property(key, value);
    }

    /**
     * Set a property to a particular value on this object.
     * To set multiple properties at once, pass an associative array
     * as the first parameter and leave out the second parameter.
     * Flags the properties as "dirty" so they will be saved to the
     * database when save() is called. 
     * @param string|array $key
     * @param string|null $value
     */
    public function set_expr(key, value = null) 
    {
        return this->_set_orm_property(key, value, true);
    }

    /**
     * Set a property on the ORM object.
     * @param string|array $key
     * @param string|null $value
     * @param bool $raw Whether this value should be treated as raw or not
     */
    protected function _set_orm_property(key, value = null, expr = false)-><Query>
    {
        var field,val;
        if typeof key != "array" {
            let key = [key : value];
        }
        for field,val in key {
            let this->_data[field] = val;
            let this->_dirty_fields[field] = val;
            if false === expr && isset this->_expr_fields[field] {
                unset this->_expr_fields[field];
            } elseif true === expr {
                let this->_expr_fields[field] = true;
            }
        }
        return this;
    }

    /**
     * Check whether the given field has been changed since this
     * object was saved.
     */
    public function isDirty(key) 
    {
        return array_key_exists(key, this->_dirty_fields);
    }

    /**
     * Check whether the model was the result of a call to create() or not
     * @return bool
     */
    public function isNew() 
    {
        return this->_is_new;
    }

    /**
     * Save any fields which have been modified on this object
     * to the database.
     */
    public function save() 
    {
        var values,id,query,success,cac,keys,c,db,row,key,value,column;
        string func = "fetch";
        let query = [];
        let keys = array_diff_key(this->_dirty_fields, this->_expr_fields);
        let values = (typeof keys == "array") ? array_values(keys) : [];

        if ! this->_is_new {
            if empty values && empty this->_expr_fields {
                return true;
            }
            let query = this->_build_update();
            let id = this->id(true);
            if (typeof id == "array") {
                let values = array_merge(values, array_values(id));
            } else {
                let values[]= id;
            }
        } else { // INSERT
            let query = this->_build_insert();
        }

        let success = self::_execute(query, values, this->_connection_name);
        let cac = self::_config[this->_connection_name]["caching_auto_clear"];
        if cac {
            self::clear_cache(this->_table_name, this->_connection_name);
        }
        // If we"ve just inserted a new record, set the ID of this object
        if this->_is_new {
            let this->_is_new = false;
            let c = this->count_null_id_columns();
            if  c != 0 {
                let db = self::getDb(this->_connection_name);
                if db->getAttribute(\PDO::ATTR_DRIVER_NAME) == "pgsql" {
                    let row = self::getLastStatement()->{func}(\PDO::FETCH_ASSOC);
                    for key,value in row {
                        let this->_data[key] = value;
                    }
                } else {
                    let column = this->_get_id_column_name();
                    // if the primary key is compound, assign the last inserted id
                    // to the first column
                    if (typeof column == "array") {
                        let column = reset(column);
                    }
                    let this->_data[column] = db->lastInsertId();
                }
            }
        }

        let this->_dirty_fields = [];
        let this->_expr_fields = [];
        return success;
    }

    /**
     * Add a WHERE clause for every column that belongs to the primary key
     */
    public function _add_id_column_conditions(query) 
    {
        var keys,key,pk;
        boolean first = true;
        let query[] = "WHERE";
        let pk   = this->_get_id_column_name();
        let keys = (typeof pk == "array") ? this->_get_id_column_name() : [ this->_get_id_column_name() ];
        for key in keys {
            if first {
                let first = false;
            }else {
                let query[] = "AND";
            }
            let query[] = this->_quote_identifier(key);
            let query[] = "= ?";
        }
        return query;
    }

    /**
     * Build an UPDATE query
     */
    protected function _build_update() 
    {
        array query = [];
        var table,key,value;
        array field_list = [];
        let table = this->_quote_identifier(this->_table_name);
        let query[] = "UPDATE ".table." SET";
        for key,value in this->_dirty_fields {
            if !array_key_exists(key, this->_expr_fields) {
                let value = "?";
            }
            let key = this->_quote_identifier(key);
            let field_list[] = key." = ".value;
        }
        let query[] = implode(", ", field_list);
        let query = this->_add_id_column_conditions(query);
        return implode(" ", query);
    }

    /**
     * Build an INSERT query
     */
    protected function _build_insert() 
    {
        array query;
        var field_list,placeholders;
        let query[] = "INSERT INTO";
        let query[] = this->_quote_identifier(this->_table_name);
        let field_list = array_map([this, "_quote_identifier"], array_keys(this->_dirty_fields));
        let query[] = "(" . implode(", ", field_list) . ")";
        let query[] = "VALUES";
        let placeholders = this->_create_placeholders(this->_dirty_fields);
        let query[] = "(".placeholders.")";
        if self::getDb(this->_connection_name)->getAttribute(\PDO::ATTR_DRIVER_NAME) == "pgsql" {
            let query[] = "RETURNING " . this->_quote_identifier(this->_get_id_column_name());
        }
        return implode(" ", query);
    }

    /**
     * Delete this record from the database
     */
    public function delete() 
    {
        var query,ids;;
        let query = [
            "DELETE FROM",
            this->_quote_identifier(this->_table_name)
        ];
        let query = this->_add_id_column_conditions(query);
        let ids = this->id(true);
        return self::_execute(implode(" ", query), (typeof ids == "array") ? array_values(ids) : [ids], this->_connection_name);
    }

    /**
     * Delete many records from the database
     */
    public function delete_many() 
    {
        // Build and return the full DELETE statement by concatenating
        // the results of calling each separate builder method.
        var query;
        let query = this->_join_if_not_empty(" ", [
            "DELETE FROM",
            this->_quote_identifier(this->_table_name),
            this->_build_where()
        ]);
        return self::_execute(query, this->_values, this->_connection_name);
    }

    // --------------------- //
    // ---  ArrayAccess  --- //
    // --------------------- //

    public function offsetExists(key) 
    {
        return array_key_exists(key, this->_data);
    }

    public function offsetGet(key) 
    {
        return this->get(key);
    }

    public function offsetSet(key, value) 
    {
        if is_null(key) {
            throw "You must specify a key/array index.";
        }
        this->set(key, value);
    }

    public function offsetUnset(key) 
    {
        unset this->_data[key];
        unset this->_dirty_fields[key];
    }

    // --------------------- //
    // --- MAGIC METHODS --- //
    // --------------------- //
    public function __get(key) {
        return this->offsetGet(key);
    }

    public function __set(key, value) {
        this->offsetSet(key, value);
    }

    public function __unset(key) {
        this->offsetUnset(key);
    }


    public function __isset(key) {
        return this->offsetExists(key);
    }

    /**
     * Magic method to capture calls to undefined class methods.
     * In this case we are attempting to convert camel case formatted 
     * methods into underscore formatted methods.
     *
     * This allows us to call ORM methods using camel case and remain 
     * backwards compatible.
     * 
     * @param  string   $name
     * @param  array    $arguments
     * @return ORM
     */
    public function __call(name, arguments)
    {
        var method;
        let method = strtolower(preg_replace("/([a-z])([A-Z])/", "$1_$2", name));
        if method_exists(this, method) {
            return call_user_func_array([this, method], arguments);
        } else {
            throw "Method ".method."() does not exist in class " . get_class(this);
        }
    }

    /**
     * Magic method to capture calls to undefined static class methods. 
     * In this case we are attempting to convert camel case formatted 
     * methods into underscore formatted methods.
     *
     * This allows us to call ORM methods using camel case and remain 
     * backwards compatible.
     * 
     * @param  string   $name
     * @param  array    $arguments
     * @return ORM
     */
    public static function __callStatic(name, arguments)
    {
        var method;
        let method = strtolower(preg_replace("/([a-z])([A-Z])/", "$1_$2", name));
        return call_user_func_array(["Query", method], arguments);
    }
}
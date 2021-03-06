namespace Aimo;
/**
 * Mysql Library via PDO
 *
 * Support manage more databases
 * Support R/W split structure
 * Support many Master databases and many salves
 *
 * <code>
 * $config = [
 *   'dsn' => 'mysql:host=localhost;dbname=cinsocrm;port=63306',
 *   'username' => 'root',
 *   'password' => '',
 *   'options'  => [
 *       PDO::MYSQL_ATTR_INIT_COMMAND => 'SET NAMES \'UTF8mb4\''
 *   ]
 * ];
 * $sql = "SELECT * FROM `user` WHERE `uid`=?";
 * Db::init($config);
 * Db::getInstance()->fetchRow($sql,[3]);
 * //Or
 * Db::getInstance('otherdb',$config)->fetchRow($sql,[3]);
 * </code>
 */
class Db
{
    /**
     * @var array
     */
     private static _instance = [];

     /**
      * @var array
      */
     private static _connections = [];
 
     /**
      * @var array
      */
     private static _config = [];
 
     /**
      * @var string
      */
     private static _table = "";
     /**
      * @var string
      */
     private static _prefix = "";

     private where = "";
     private fields = "";
     private orderBy = "";
     private groupBy = "";
     private limit = "";
 
     /**
      * Db constructor.
      *
      * @param string name
      * @param array config
      */
     public function __construct(string! name, array config = [])->void
     {
         if !empty config {
             self::init(config, name);
         }
     }
 
     /**
      * Initialize config
      *
      * <code>
      * Db::init([
      *   'dsn' => 'mysql:host=localhost;dbname=cinsocrm;port=63306',
      *   'username' => 'root',
      *   'password' => 'sa',
      *   'options'  => [
      *       PDO::MYSQL_ATTR_INIT_COMMAND => 'SET NAMES \'UTF8mb4\''
      *   ]
      * ]);
      * </code>
      * @param array config
      * @param string name
      */
     public static function init(array config, string! name = "default")->void
     {
         let self::_config[name]=config;
         if isset config["prefix"] {
             let self::_prefix = config["prefix"];
         }
     }
 
     /**
      * Get the database instance
      *
      * Support One or many database instance
      *
      * <code>
      * $db2 = Db::getInstance('mydb', [
      *   'dsn' => 'mysql:host=localhost;dbname=cinsocrm;port=63306',
      *   'username' => 'root',
      *   'password' => 'sa',
      *   'options'  => [
      *       PDO::MYSQL_ATTR_INIT_COMMAND => 'SET NAMES \'UTF8mb4\''
      *   ]
      * ]);
      * //or
      * $config = [
      *   'dsn' => 'mysql:host=localhost;dbname=cinsocrm;port=63306',
      *   'username' => 'root',
      *   'password' => '',
      *   'options'  => [
      *       PDO::MYSQL_ATTR_INIT_COMMAND => 'SET NAMES \'UTF8mb4\''
      *   ]
      * ];
      * Db::init($config);
      * $db = Db::getInstance();
      * </code>
      * @param name
      * @param config
      * @return Db
      */
     public static function getInstance(string! name = "default", array config = [])-><Db>
     {
         if !empty config  {
            self::init(config, name);
         }
         if !isset self::_instance[name] {
             let self::_instance[name] = new self(name, config);
         }
         return self::_instance[name];
     }
 
     /**
      * Simple way to get database instance 
      *
      * <code>
      * $user = Db::name('user')->where('uid=3')->find();
      * </code>
      *
      * @param string table
      * @param string name
      * @param array config
      * @return Db
      */
     public static function name(string! table, string! name="default", array config = [])-><Db>
     {
         let self::_table = strtolower(table);
         return self::getInstance(name, config);
     }
 
     /**
      * Connect to MySQL Server via PDO
      *
      * @param array config
      * @return \PDO
      */
     protected function connect(array config)
     {
         var e;
         try {
             return new \PDO(config["dsn"], config["username"],config["password"], config["options"]);
         }catch \PDOException,e {
             die("Connection failed: " . e->getMessage());
         }
     }
     
     /**
      * Get the real table name
      */
     private function getTableName()->string
     {
        var prefix;
        if fetch prefix, self::_config["prefix"] {
             return (string) prefix.self::_table;
        }else{
            return (string) self::_table;
        }
     }
 
     /**
      * Get write connection
      *
      * <code>
      * $db = Db::getInstance();
      * $connection = $db->getWriteConnection();
      * </code>
      *
      * @param string name
      * @param array config
      * @return PDO
      * @throws Exception
      */
     public function getWriteConnection(string! name = "default",array config = [])
     {
         if empty config {
             let config = typeof self::_config[name] == "array" ? self::_config[name] : [];
         }else{
             self::init(config, name);
         }
         if isset config["dsn"] {
             if !isset self::_connections[name]["master"] {
                 let self::_connections[name]["master"]=this->connect(config);
             }
             return self::_connections[name]["master"];
         }
         if isset config["master"] {
             if !isset self::_connections[name]["master"] {
                 let config = this->randByWeight(config);
                 let self::_connections[name]["master"]=this->connect(config);
             }
             return self::_connections[name]["master"];
         }
         throw new \Exception("Db config error");
     }
 
     /**
      * Get the read connection
      *
      * <code>
      * $db = Db::getInstance();
      * $connection = $db->getReadConnection();
      * </code>
      *
      * @param string name
      * @param array config
      * @return PDO
      * @throws Exception
      */
     public function getReadConnection(string! name = "default",array config = [])
     {
         if empty config {
            let config = typeof self::_config[name] == "array" ? self::_config[name] : [];
         }else{
             self::init(config, name);
         }
         if isset config["dsn"] {
             if isset self::_connections[name]["master"] {
                 return self::_connections[name]["master"];
             }else{
                 return this->getWriteConnection(name,config);
             }
         }
         if isset config["salves"] {
             if !isset self::_connections[name]["slave"] {
                 let config = this->randByWeight(config);
                 let self::_connections[name]["slave"]=this->connect(config);
             }
             return self::_connections[name]["slave"];
         }
         throw new \Exception("Db config error");
     }

     /**
      * Get connection via SQL Statement
      */
     public function getConnection(string! sql)
     {
        string operation;
         let operation = (string) strtoupper(substr(trim(sql),0,6));
         switch operation {
             case "INSERT":
             case "REPLAC":
             case "DELETE":
             case "UPDATE":
             return this->getWriteConnection();
         }
         return this->getReadConnection();
     }

     /**
      * Query a table field
      *
      * <code>
      * $db = Db::getInstance();
      * $sql = "SELECT `cellphone` FROM `user` WHERE `uid`=?";
      * $cellphone = $db->fetchOne($sql, [3]);
      * </code>
      *
      * @param string sql
      * @param array params
      * @return string
      * @throws Exception
      */
     public function fetchOne(string! sql,array params = [])->string
     {
         var connection, statement, result, row;
         let connection = this->getConnection(sql);
         let statement = connection->prepare(sql);
         statement->execute(params);
         let result = statement->{"fetch"}(\PDO::FETCH_NUM);
         if typeof row == "array" {
            return isset row[0] ? (string)row[0] : "";
         } else {
             return "";
         }
     }
 
     /**
      * Query and return a row
      *
      * <code>
      * $db = Db::getInstance();
      * $sql = "SELECT * FROM `user` WHERE `uid`=?";
      * $user = $db->fetchRow($sql, [3]);
      * </code>
      *
      * @param string sql
      * @param array params
      * @return mixed
      * @throws Exception
      */
     public function fetchRow(string! sql, array params = [])->array
     {
        var connection,statement,row;
        let connection = this->getConnection(sql);
         let statement = connection->prepare(sql);
         statement->execute(params);
         let row =  statement->{"fetch"}(\PDO::FETCH_ASSOC);
         if typeof row == "array" {
            return row;
         }else{
            return [];
         }
     }
 
     /**
      * Query and return a columns
      *
      * <code>
      * $db = Db::getInstance();
      * $sql = "SELECT `uid` FROM `user` WHERE `mobile`=?";
      * $uids = $db->fetchCols($sql, ['1233234']);
      * //array [1,2,3,4]
      * $uids = $db->fetchCols($sql, ['1233234'], ',');
      * //string 1,2,3,4
      * </code>
      *
      * @param string sql
      * @param array params
      * @param string split
      * @return string|array
      * @throws Exception
      */
     public function fetchCols(string! sql,array params = [],string split = "")
     {
         var connection,results,row,statement;
         let results = [];
         let connection = this->getConnection(sql);
         let statement = connection->prepare(sql);
         statement->execute(params);
         loop {
            let row = statement->{"fetch"}(\PDO::FETCH_NUM);
            if empty row {
                break;
            }
            if isset row[0] {
                let results[]=row[0];
            }
         }
         return empty split ? results : implode(split, results);
     }
 
     /**
      * Query two or more field as a assocation array
      *
      * <code>
      * $db   = Db::getInstance();
      * $sql  = "SELECT `uid`,`truename` FROM `user` WHERE `gender`=?";
      * $uids = $db->fetchAssoc($sql, ['Male']);
      * //array ['2'=>'Jack','4'=>'John']
      * $sql  = "SELECT `uid`,`truename`,`avatar` FROM `user` WHERE `gender`=?";
      * $uids = $db->fetchAssoc($sql, ['Male']);
      * //result [
        // '2' => [
        //    'uid' => 2,
        //    'truename'=>'Jack',
        //    'avatar'=>'avatar.jpg'
        //  ],
        // '4' => [
        //    'uid' => 4,
        //    'truename'=>'John',
        //    'avatar'=>'avatar.png'
        //  ]
        //]
      * </code>
      *
      * @param string sql
      * @param array params
      * @return array
      * @throws Exception
      */
     public function fetchAssoc(string! sql, array params = [])->array
     {
         var connection, results,row,keys,key, statement;
         let results = [];
         let connection = this->getConnection(sql);
         let statement = connection->prepare(sql);
         statement->execute(params);
         let row = statement->{"fetch"}(\PDO::FETCH_ASSOC);
         if empty row {
             return [];
         }
         let keys = array_keys(row);
         let key = keys[0];
         if count(row) > 2 {
            let results[row[key]]=row;
            loop {
                let row = statement->{"fetch"}(\PDO::FETCH_ASSOC);
                if empty row {
                    break;
                }
                let results[row[key]]=row;
            }
         }else{
            let results[row[key]]=row[keys[1]];
            loop {
                let row = statement->{"fetch"}(\PDO::FETCH_ASSOC);
                if empty row {
                    break;
                }
                let results[row[key]]=row[keys[1]];
            }
         }
        return typeof results == "array" ? results : [];
     }
 
     /**
      * Query all row by SQL Statement
      *
      * <code>
      * $db = Db::getInstance();
      * $sql = "SELECT * FROM `user` WHERE `score`>? LIMIT 100";
      * $users = $db->fetchAll($sql, [0]);
      * </code>
      * @param string sql
      * @param array params
      * @return array
      * @throws Exception
      */
     public function fetchAll(string! sql, array params=[])->array
     {
         var connection, data, statement;
         let connection = this->getConnection(sql);
         let statement = connection->prepare(sql);
         statement->setFetchMode(\PDO::FETCH_ASSOC);
         statement->execute(params);
         let data = statement->fetchAll();
         return empty(data) ? [] : data;
     }

     private function buildSql()->string
     {   
         string sql,table,fields;
         let table  = (string) this->getTableName();
         let fields = empty this->fields ? '*' : this->fields;
         let sql = "SELECT ".fields." FROM ".table;
         if !empty this->where {
             let sql.= " WHERE ".this->where;
         }
         if !empty this->groupBy {
            let sql.= " GROUP BY ".this->groupBy;
        }
        if !empty this->orderBy {
            let sql.= " ORDER BY ".this->orderBy;
        }
        if !empty this->limit {
            let sql.= " LIMIT ".this->limit;
        }
        return sql;
     }

     private function clearSql()
     {
         let this->fields = "";
         let this->where = "";
         let this->groupBy = "";
         let this->orderBy = "";
         let this->limit = "";
     }

     /**
      * Simple way to get database instance 
      *
      * <code>
      * $user = Db::name('user')->where('uid=3')->getField();
      * </code>
      *
      * @param string table
      * @param string name
      * @param array config
      * @return Db
      */
     public function getField()
     {
         string sql;
         var data;
         let sql = (string) this->buildSql();
         let data = this->fetchAssoc(sql);
         this->clearSql();
         return data;
     }

     /**
      * Simple way to get many rows 
      *
      * <code>
      * $user = Db::name('user')->where('score>0')->select();
      * </code>
      *
      * @return array
      */
     public function select()
     {
         string sql;
         var data;
         let sql = (string) this->buildSql();
         var_dump(sql);
         let data = this->fetchAll(sql);
         this->clearSql();
         return data;
     }
    
     /**
      * Simple way to get one rows 
      *
      * <code>
      * $user = Db::name('user')->field('truename,cellphone')->where('uid=2')->find();
      * </code>
      *
      * @return array
      */
     public function find()
     {
         string sql;
         var data;
         let this->limit = " LIMIT 1";
         let sql = (string) this->buildSql();
         let data = this->fetchOne(sql);
         this->clearSql();
         return data;
     }

     /**
      * Set fields to fetch
      *
      * <code>
      * $user = Db::name('user')->field('truename,cellphone')->where('uid=2')->find();
      * </code>
      *
      * @return array
      */
     public function fields(string! fields)-><Db>
     {
         let this->fields = fields;
         return this;
     }

     /**
      * where condition 
      *
      * <code>
      * $user = Db::name('user')->field('truename,cellphone')->where('uid=2')->find();
      * </code>
      *
      * @return array
      */
     public function where(string! where)-><Db>
     {
         let this->where = where;
         return this;
     }

     /**
      * Order by implement
      *
      * <code>
      * $user = Db::name('user')->field('uid,truename,score')->where('`status`=1')->order('score DESC')->select();
      * </code>
      *
      * @return array
      */
      public function order(string! order)-><Db>
      {
          let this->orderBy = order;
          return this;
      }

     /**
      * Group by implement
      *
      * <code>
      * $user = Db::name('user')->field('level,COUNT(1)')->where('`status`=1')->group('level')->getField();
      * </code>
      *
      * @return array
      */
     public function group(string! group)-><Db>
     {
         let this->groupBy = group;
         return this;
     }

     /**
      * Simple way to get many rows 
      *
      * <code>
      * $user = Db::name('user')->where('score>0')->limit('10')->select();
      * $user = Db::name('user')->where('score>0')->limit('5,10')->select();
      * </code>
      *
      * @return array
      */
     public function limit(string limit)-><Db>
     {
         let this->limit = (string) limit;
         return this;
     }
 
     /**
      * 根据权重获取配置项目
      *
      * @param array array
      * @param string key
      * @return array|mixed
      */
     private function randByWeight(array data, string! key = "weight")->array
     {
         if empty data {
             return [];
         }
         var buckets,weights,index,seed,chrindex,weight;
         let buckets = "";
         let weights = array_column(data, key);
         let weights = typeof weights == "array" ? weights : [];
         for index,weight in weights {
             let buckets .= str_repeat(chr(index+65), weight);
         }
         let buckets = str_shuffle(buckets);
         let seed = substr(buckets, 0, 1);
         let chrindex = ord(seed);
         let index = chrindex - 65;
         if isset data[index] {
             return typeof data[index] == "array" ? data[index] : (array) data[0];
         } else {
            return (array) data[0];
         }
     }
}
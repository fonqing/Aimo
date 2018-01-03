namespace Aimo\Db;
class ResultSet implements \Countable, \IteratorAggregate, \ArrayAccess, \Serializable {
        /**
         * The current result set as an array
         * @var array
         */
        protected _results = [];

        /**
         * Optionally set the contents of the result set by passing in array
         * @param array $results
         */
        public function __construct(array results = []) 
        {
            this->set_results(results);
        }

        /**
         * Set the contents of the result set by passing in array
         * @param array $results
         */
        public function set_results(array results) 
        {
            let this->_results = results;
        }

        /**
         * Get the current result set as an array
         * @return array
         */
        public function get_results() 
        {
            return this->_results;
        }

        /**
         * Get the current result set as an array
         * @return array
         */
        public function as_array() 
        {
            return this->get_results();
        }
        
        /**
         * Get the number of records in the result set
         * @return int
         */
        public function count() 
        {
            return count(this->_results);
        }

        /**
         * Get an iterator for this object. In this case it supports foreaching
         * over the result set.
         * @return \ArrayIterator
         */
        public function getIterator() 
        {
            return new \ArrayIterator(this->_results);
        }

        /**
         * ArrayAccess
         * @param int|string $offset
         * @return bool
         */
        public function offsetExists(offset) 
        {
            return isset this->_results[offset];
        }

        /**
         * ArrayAccess
         * @param int|string $offset
         * @return mixed
         */
        public function offsetGet(offset) 
        {
            return this->_results[offset];
        }
        
        /**
         * ArrayAccess
         * @param int|string $offset
         * @param mixed $value
         */
        public function offsetSet(offset, value) 
        {
            let this->_results[offset] = value;
        }

        /**
         * ArrayAccess
         * @param int|string $offset
         */
        public function offsetUnset(offset) 
        {
            unset(this->_results[offset]);
        }

        /**
         * Serializable
         * @return string
         */
        public function serialize()
        {
            return serialize(this->_results);
        }

        /**
         * Serializable
         * @param string $serialized
         * @return array
         */
        public function unserialize(serialized) 
        {
            return unserialize(serialized);
        }

        /**
         * Call a method on all models in a result set. This allows for method
         * chaining such as setting a property on all models in a result set or
         * any other batch operation across models.
         * @example ORM::for_table('Widget')->find_many()->set('field', 'value')->save();
         * @param string $method
         * @param array $params
         * @return ResultSet
         */
        public function __call(method, params = [])-><ResuleSet> 
        {
            var model;
            for model in this->_results {
                if method_exists(model, method) {
                    call_user_func_array([model, method], params);
                } else {
                    throw "Method ".method."() does not exist in class " . get_class(this);
                }
            }
            return this;
        }
    }
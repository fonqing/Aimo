namespace Aimo\Db;
class Helper {
        protected subject;
        protected search;
        protected replace;
        /**
         * Get an easy to use instance of the class
         * @param string $subject
         * @return \self
         */
        public static function value(subject)-><Helper>
        {
            return new self(subject);
        }

        /**
         * Shortcut method: Replace all occurrences of the search string with the replacement
         * string where they appear outside quotes.
         * @param string $search
         * @param string $replace
         * @param string $subject
         * @return string
         */
        public static function str_replace_outside_quotes(search, replace, subject) 
        {
            return self::value(subject)->replace_outside_quotes(search, replace);
        }

        /**
         * Set the base string object
         * @param string $subject
         */
        public function __construct(subject) -> void
        {
            let this->subject = (string) subject;
        }

        /**
         * Replace all occurrences of the search string with the replacement
         * string where they appear outside quotes
         * @param string $search
         * @param string $replace
         * @return string
         */
        public function replace_outside_quotes(search, replace) 
        {
            let this->search = search;
            let this->replace = replace;
            return this->_str_replace_outside_quotes();
        }

        /**
         * Validate an input string and perform a replace on all ocurrences
         * of $this->search with $this->replace
         * @author Jeff Roberson <ridgerunner@fluxbb.org>
         * @link http://stackoverflow.com/a/13370709/461813 StackOverflow answer
         * @return string
         */
        protected function _str_replace_outside_quotes()
        {
            var re_valid,re_parse;
            let re_valid = "/^(?:\"[^\"\\\\]*(?:\\\\.[^\"\\\\]*)*\" | '[^'\\\\]*(?:\\\\.[^'\\\\]*)*'| [^'\"\\\\]+)* \z /sx";
            if preg_match(re_valid, this->subject) {
                throw "Subject string is not valid in the replace_outside_quotes context.";
            }
            let re_parse = "/( \"[^\"\\\\]*(?:\\\\.[^\"\\\\]*)*\" | '[^'\\\\]*(?:\\\\.[^'\\\\]*)*' ) | ([^'\"\\\\]+) /sx";
            return preg_replace_callback(re_parse, [this, "_str_replace_outside_quotes_cb"], this->subject);
        }

        /**
         * Process each matching chunk from preg_replace_callback replacing
         * each occurrence of $this->search with $this->replace
         * @author Jeff Roberson <ridgerunner@fluxbb.org>
         * @link http://stackoverflow.com/a/13370709/461813 StackOverflow answer
         * @param array $matches
         * @return string
         */
        protected function _str_replace_outside_quotes_cb(matches) 
        {
            // Return quoted string chunks (in group $1) unaltered.
            if isset matches[1] {
                return matches[1];
            } 
            // Process only unquoted chunks (in group $2).
            return preg_replace("/". preg_quote(this->search, "/") ."/", this->replace, matches[2]);
        }
    }
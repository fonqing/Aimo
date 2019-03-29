namespace Aimo;

class Html {
    /**
     * HTML标签
     *
     * 生成HTML标签
     *
     * <code>
     * echo Html::tag('a',['href'=>'#','class'=>'anchor'],'文字');
     * //Will output : <a href="#" class="anchor">文字</a>
     * echo Html::tag('input',['type'=>'text','name'=>'name']);
     * /Will output : <input type="text" name="name" />
     * </code>
     *
     * @param string tagName
     * @param array attributes
     * @param string inner inner text
     */
    public static function tag(string! tagName, array! attributes, string! inner = "") -> string
    {
        var attrs = "";
        string selfCloseTags = ",meta,base,br,img,input,param,link,area,hr,col,frame,embed,";
        let tagName = (string) trim(tagName);
        let tagName = (string) strtolower(tagName);
        let tagName = (string) preg_replace("/[^a-z1-6]+/", "", tagName);
        let attrs   = self::renderAttributes(attributes);
        return ( selfCloseTags.index(','.tagName.',') === false ) ?
            "<".tagName.attrs.">".inner."</".tagName.">" :
            "<".tagName.attrs." />";
    }

    /**
     * Build attribute string for element
     *
     * Render html tag attributes
     *
     * @access protected
     * @param array  atts
     * @return string
     */
    protected static function renderAttributes(array! atts = []) -> string
    {
        string attributes = "";
        var name,value;
        for name,value in atts {
            let value    = htmlspecialchars(value, ENT_QUOTES, "UTF-8");
            let attributes .= " ".name."=\"".value."\"";
        }
        return attributes;
    }

    /**
     * 魔术方法实现其他方法
     *
     * <code>
     * echo Html::a(['href'=>'#','class'=>'anchor'],'文字');
     * //Will output : <a href="#" class="anchor">文字</a>
     * echo Html::input(['type'=>'text','name'=>'name']);
     * /Will output : <input type="text" name="name" />
     * </code>
     */
    public static function __callStatic(tagName, args)
    {
        int c;
        let c = (int) count(args),
            tagName = preg_replace("/[^a-z1-6]+/", "", strtolower(tagName));
        if empty tagName {
            throw "TagName can't be empty";
        }
        array_unshift(args, tagName);
        return call_user_func_array("Aimo\\Html::tag", args);
    }

}

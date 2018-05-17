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
     * echo Html::tag('input',['type'=>'text','name'=>'name'], '', true);
     * /Will output : <input type="text" name="name" />
     * </code>
     *
     * @param string tagName
     * @param array attributes
     * @param string inner inner text
     * @param boolean selfClose
     */
    public static function tag(string! tagName, array! attributes, string! inner = "", boolean selfClose = false) -> string
    {
        var attr;
        let attr = self::renderAttributes(attributes);
        return selfClose ?
            "<".tagName.attr." />" :
            "<".tagName.attr.">".inner."</".tagName.">";
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
        var c;
        let c = count(args),
            tagName = preg_replace("/[^a-z1-6]+/","",strtolower(tagName));
        if empty tagName {
            throw "TagName can't empty";
        }
        string single = ",input,hr,br,img,";
        if single->index(",".tagName.",") {
            let args[]= "";
            let args[]= true;
        }else{
            if c < 2 {
                throw "Html::".tagName." need two params";
            }
        }
        array_unshift(args, tagName);
        return call_user_func_array("Aimo\\Html::tag",args);
    }

}

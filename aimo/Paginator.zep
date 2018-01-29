namespace Aimo;
/**
 * A flexible Paginator Class
 *
 * @author <Eric Wong,fonqing@gmail.com>
 * @update 2018/1/29
 *
 * <code>
 * <style type="text/css">
 * .pagination { display:block;font-size:14px;font-family:"Verdana";overflow:hidden;float:right;clear:both;list-style:none;}
 * .pagination li { float:left;margin-right:5px;}
 * .pagination li a { display:block;text-decoration:none;color:#333;padding:3px 6px;border:1px solid #ddd;background-color:#eee;font-size:14px;}
 * .pagination li.disabled a { display:inline-block;padding:3px 5px;border:1px solid #fff;background-color:#fff;font-size:14px;}
 * .pagination li.active a { border-color:#888;background-color:#aaa;color:#fff;}
 * </style>
 * </code>
 */
class Paginator
{
    /**
     * @var string Previous page label
     */
    private prevText  = "&lt;";

    /**
     * @var string Next page label
     */
    private nextText  = "&gt;";

    /**
     * @var string First page label
     */
    private firstText = "&lt;&lt;";

    /**
     * @var string Last page label
     */
    private lastText  = "&gt;&gt;";

    //for bootstrap 4.0 className
    /**
     * @var string Active page link className
     */
    private activeClass = "page-item active";

    /**
     * @var string Disabled page link className
     */
    private disabledClass = "page-item disabled";

    /**
     * @var string Normal page link className
     */
    private normalClass = "page-item";

    /**
     * @var string Anchor className
     */
    private anchorClass = "page-link";

    /**
     * TODO: Support Javascript function to load page & data
     */
    private jsFunc      = "";

    /**
     * @var string Pagination Container HTML
     */
    private wrapTpl     = "<ul class=\"pagination\">%INNER%</ul>";

    /**
     * @var string Pagelist Element template
     */
    private itemTpl     = "<li class=\"%CLASS%\">%TEXT%</li>";
    /**
     * @var string Pagination infomation item template
     */
    //private infoTpl   = "<li class=\"page-item disabled\" title=\"共 %TOTAL% 条记录，每页 %PAGESIZE% 条\"><a class=\"page-link\">第 %PAGE% 页/共 %PAGECOUNT% 页</a></li>";
    private infoTpl     = "<li class=\"page-item disabled\" title=\"%TOTAL% Records,%PAGESIZE% per Page\"><a class=\"page-link\">Page %PAGE% of %PAGECOUNT%</a></li>";

    /**
     * @var int Records count
     */
    private total       = 0;

    /**
     * @var int How many records per page
     */
    private pageSize    = 20;

    /**
     * @var int How many page anchor in pagelist / 2
     */
    private adjacentNum = 2;

    /**
     * @var int How many pages
     */
    private pageCount;

    /**
     * @var int Current page
     */
    private page        = 1;

    /**
     * @var string Page variable in _GET
     */
    private pageParam   = "page";

    /**
     * @var string Pagination html
     */
    private html        = "";

    /**
     * Constructor
     *
     * <code>
     * $pageSize = 20;
     * $totalRecords = 376;
     * $pager = new Aimo\Paginator($pageSize, $totalRecords);
     * $pagehtml = $pager->getPageHtml();
     * </code>
     *
     * @param int pageSize Count per page
     * @param int total    Total count
     */
    public function __construct(int! pageSize,int! total)
    {
        int page;
        let pageSize        = (int) pageSize;
        let this->pageSize  = pageSize<1 ? this->pageSize : pageSize;
        let this->total     = (int) total;
        let this->pageCount = ceil( this->total / this->pageSize );
        let page            = isset _GET[this->pageParam] ? (int) _GET[this->pageParam] : 1;
        let this->html      = "";
        let this->page      = min(this->pageCount, max(1, page));
    }

    /**
     * Set config variable
     *
     * <code>
     * $pager->config('prevText','Previous');
     * $pager->config('wrapTpl','<div class="pagination">%INNER%</div>');
     * </code>
     */
    public function config(string! name,var value)->void
    {
        if property_exists(this, name) {
            let this->{name} = value;
        }
    }

    /**
     * More config to set
     *
     * <code>
     * $pager->init([
     *    'prevText'    => 'Previous',
     *    'adjacentNum' => 3,
     *    'wrapTpl'     => '<div class="pagination">%INNER%</div>'
     * ]);
     * </code>
     */
    public function init(array! configs)->void
    {
        var name,value;
        for name,value in configs {
            this->config(name, value);
        }
    }

    /**
     * Prepare for building Url
     */
    private function getUrl(string! append="")->string
    {
        var url,parse,params;
        //static url;
        //if empty url {
        let url   = _SERVER["REQUEST_URI"].(strpos(_SERVER["REQUEST_URI"],"?")?"":"?");
        let url   = filter_var(url, FILTER_SANITIZE_URL);
        let parse = parse_url(url);
        if isset parse["query"] {
            parse_str(parse["query"], params);
            unset(params[this->pageParam]);
            let url = parse["path"]."?".http_build_query(params);
        }
        let url = url.(strpos(url, "?") ? (strpos(url, "=")?"&":"") : "");
        //}
        return (string) url.append;
    }

    /**
     * Format string to create html
     *
     * @param string tpl
     * @param array data
     * @return string
     */
    private static function format(string! tpl,array! data)->string
    {
        return (string) str_replace( array_keys(data), array_values(data), tpl);
    }

    /**
     * Detect browser user agent
     *
     * @return bool
     */
    private static function isMobile()->bool
    {
        return (stripos(_SERVER["HTTP_USER_AGENT"],"android")>0 || stripos(_SERVER["HTTP_USER_AGENT"],"iphone")>0);
    }

    /**
     * Parse the first page
     */
    private function firstPage()->void
    {
        if this->page == 1 {
            let this->html = this->html.self::format(this->itemTpl, [
                "%CLASS%" : this->disabledClass,
                "%TEXT%"  : "<a class=\"".this->anchorClass."\">".this->firstText."</a>"
            ]);
        } else {
            var url;
            let url  = this->getUrl(this->pageParam."=1");
            let this->html = this->html.self::format(this->itemTpl, [
                "%CLASS%" : this->normalClass,
                "%TEXT%"  : "<a class=\"".this->anchorClass."\" href=\"" . url."\">" . this->firstText . "</a>"
            ]);
        }
    }

    /**
     * Parse the last page
     */
    private function lastPage()->void
    {
        if this->page == this->pageCount {
            let this->html = this->html.self::format(this->itemTpl, [
                "%CLASS%" : this->disabledClass,
                "%TEXT%"  : "<a class=\"".this->anchorClass."\">".this->lastText."</a>"
            ]);
        } else {
            var url;
            let url = this->getUrl(this->pageParam."=".this->pageCount);
            let this->html = this->html.self::format(this->itemTpl, [
                "%CLASS%" : this->normalClass,
                "%TEXT%"  : "<a class=\"".this->anchorClass."\" href=\"" . url."\">" . this->lastText . "</a>"
            ]);
        }
    }

    /**
     * Parse the previous page
     */
    private function prevPage()->void
    {
        if this->page == 1 {
            let this->html = this->html.self::format(this->itemTpl, [
                "%CLASS%" : this->disabledClass,
                "%TEXT%"  : "<a class=\"".this->anchorClass."\">".this->prevText."</a>"
            ]);
        } else {
            var url;
            let url = this->getUrl(this->pageParam."=".(this->page - 1));
            let this->html = this->html.self::format(this->itemTpl, [
                "%CLASS%" : this->normalClass,
                "%TEXT%"  : "<a class=\"".this->anchorClass."\" href=\"" . url."\">" . this->prevText . "</a>"
            ]);
        }
    }

    /**
     * Parse the next page
     */
    private function nextPage()->void
    {
        if this->page < this->pageCount {
            var url;
            let url = this->getUrl(this->pageParam."=".(this->page+1));
            let this->html = this->html.self::format(this->itemTpl, [
                "%CLASS%" : this->normalClass,
                "%TEXT%"  : "<a class=\"".this->anchorClass."\" href=\"" . url."\">" . this->nextText . "</a>"
            ]);
        } else {
            let this->html = this->html.self::format(this->itemTpl, [
                "%CLASS%" : this->disabledClass,
                "%TEXT%"  : "<a class=\"".this->anchorClass."\">".this->nextText."</a>"
            ]);
        }
    }

    /**
     * Parse the pagination infomation block
     */
    private function headBlock()->void
    {
        let this->html = this->html.self::format(this->infoTpl, [
            "%TOTAL%"     : this->total,
            "%PAGE%"      : this->page,
            "%PAGECOUNT%" : this->pageCount,
            "%PAGESIZE%"  : this->pageSize
        ]);
    }

    /**
     * Parse the first block
     */
    private function firstBlock()->void
    {
        if this->page > ( this->adjacentNum+1 )  {
            let this->html = this->html.self::format(this->itemTpl, [
                "%CLASS%" : this->normalClass,
                "%TEXT%"  : "<a class=\"".this->anchorClass."\" href=\"".this->getUrl(this->pageParam."=1")."\">1</a>"
            ]);
        }
        if this->page > ( this->adjacentNum+2 ) {
            let this->html = this->html.self::format(this->itemTpl,[
                "%CLASS%" : this->disabledClass,
                "%TEXT%"  : "<a class=\"".this->anchorClass."\">...</a>"
            ]);
        }
    }

    /**
     * Parse the middle part
     */
    private function middleBlock()->void
    {
        int pageMin,pageMax;
        let pageMin = ( this->page > this->adjacentNum ) ? ( this->page - this->adjacentNum ) : 1;
        let pageMax = ( this->page < (this->pageCount-this->adjacentNum)) ? (this->page+this->adjacentNum) : this->pageCount ;
        var url;
        let url  = this->getUrl();
        while pageMin <= pageMax {
            if( pageMin == this->page ) {
                let this->html = this->html.self::format(this->itemTpl, [
                    "%CLASS%" : this->activeClass,
                    "%TEXT%"  : "<a class=\"".this->anchorClass."\">".pageMin."</a>"
                ]);
            } else {
                let this->html = this->html.self::format(this->itemTpl, [
                    "%CLASS%" : this->normalClass,
                    "%TEXT%"  : "<a class=\"".this->anchorClass."\" href=\"" . url .this->pageParam."=" . pageMin . "\">" . pageMin . "</a>"
                ]);
            }
            let pageMin = pageMin+1;
        }
    }

    /**
     * Render last part
     */
    private function lastBlock()->void
    {
        if this->page < (this->pageCount - this->adjacentNum - 1) {
            let this->html = this->html.self::format(this->itemTpl, [
                "%CLASS%" : this->disabledClass,
                "%TEXT%"  : "<a class=\"".this->anchorClass."\">...</a>"
            ]);
        }
        if this->page < (this->pageCount-this->adjacentNum ) {
            var url;
            let url = this->getUrl(this->pageParam."=".this->pageCount);
            let this->html = this->html.self::format(this->itemTpl, [
                "%CLASS%" : this->normalClass,
                "%TEXT%"  : "<a class=\"".this->anchorClass."\" href=\"".url."\">".this->pageCount."</a>"
            ]);
        }
    }

    /**
     * Build page HTML code
     */
    public function getPageHtml()->string
    {
        if self::isMobile() {
            this->firstPage();
            this->prevPage();
            this->headBlock();
            this->nextPage();
            this->lastPage();
        } else {
            this->headBlock();
            this->prevPage();
            this->firstBlock();
            this->middleBlock();
            this->lastBlock();
            this->nextPage();
        }
        return self::format(this->wrapTpl, [
            "%INNER%" : this->html
        ]);
    }
}
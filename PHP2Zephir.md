# 从PHP到Zephir快速指引
本文旨在让更多的开发人员尽快熟悉Zephir，并使用Zephir加速自己的代码。
## 语法差异
     变量去掉$前缀，并且必须声明。快速声明可以使用var
	 将PHP程序中的单引号全部换为双引号
	 Zephir不支持显示引用，如PDO中的bindParam是不被支持的，但是array_push这些是可以的。
	 变量赋值全部改为 let 前关键字
	 在Zephir中可以直接调用PHP的内置函数，函数返回值赋值必须使用var声明
	 在Zephir中可以直接访问PHP的全局变量
	 在Zephir中不可以使用魔术变量如：__FILE__,__DIR__,__CLASS__,__NAMESPACE__ 
     zephir的每一个文件必须由一个类组成，类名就是文件名，扩展名是zep。
```
//Zephir的变量必须声明，静态变量支持直接使用变量类型修饰符，不确定的动态变量可以使用var声明
var data;
array a1 = ["a","b","c"];
array a2 = ["name":"Eric","age":"18"];
char z = 'a';
int i = 0;
unsigned long my_number = 2147483648;
boolean isnew = false;
var post;
let post = _SERVER;//访问PHP的全局变量
//遍历数组
var key,value；
for key,value in post {
       echo key.":".value."<br>";
}
//字符串必须使用双引号包围，单引号只用在包围char类型一个字符。这一点要特别注意
string name = "a,b,c,d";
//在zephir中可以直接调用php的内置函数。
//注意：将php的内置函数返回值赋值给变量时，变量必须声明为var，因为PHP手册中可以看出，PHP的函数返回值并不是类型一致的。
let data = explode(",",name);
//empty不是PHP中的empty函数，它是zephir的一个语法结构用来判断一个变量是null，空字符串或者空数组
if empty data {
    echo "Is empty";
}
//isset不是PHP中的isset函数，它是zephir的一个语法结构用来判断一个数组的某个索引是否被设置或者对象的属性存不存在
if isset data[2] {
    echo "Is empty";
}
```
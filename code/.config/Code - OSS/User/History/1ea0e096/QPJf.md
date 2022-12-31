---
title: "c++中string转char时的传参问题"
date: 2022-11-11T20:31:27+08:00
draft: false
tags: ["cpp","leetcode"]
---
# string类型字符串转char型时候的函数传参问题
> 力扣1704题 给你一个偶数长度的字符串 `s` 。将其拆分成长度相同的两半，前一半为 `a` ，后一半为 `b` 。  
> 两个字符串 相似 的前提是它们都含有相同数目的元音`（'a'，'e'，'i'，'o'，'u'，'A'，'E'，'I'，'O'，'U'）`。注意，s 可能同时含有大写和小写字母。  
如果 a 和 b 相似，返回 true ；否则，返回 false 。  

### 问题：当我试图使用哈希表来查找的时候，提示unordered_map的find()报错 
```
Line 20: Char 29: error: no matching member function for call to 'find'
``` 
### 解决：[C++ map no matching member function for call to 'find' when used for a string](https://stackoverflow.com/questions/66347594/c-map-no-matching-member-function-for-call-to-find-when-used-for-a-string)
类std::map的成员函数find的形参类型是const std::string &。但是使用的是char类型的参数，并且没有从char类型到std::string类型的隐式转换。
加入
```
const char item[] = { s[i], '\0' };
```
或者把原来的s[i]替换为`std::string(1, s[i])`

```
class Solution {
public:
    bool halvesAreAlike(string s) {
        unordered_map<string,string> hashtable{{"a","true"},{"e","true"},{"i","true"},{"o","true"},{"u","true"},{"A","true"},{"E","true"},{"I","true"},{"O","true"},{"U","true"}};
        int length = s.size();
        int a=0;
        int b=0;
        for(int i=0;i<length/2;++i){
            const char item[] = { s[i], '\0' };
            auto it=hashtable.find(item);
            if (it!=hashtable.end()) {
                ++a; 
            }      
        }
        for(int i=length/2;i<length;++i){
            const char item[] = { s[i], '\0' };
            auto it=hashtable.find(item);
            if (it!=hashtable.end()) {
                ++b; 
            }      
        }
        return a==b; 
    }
};
```
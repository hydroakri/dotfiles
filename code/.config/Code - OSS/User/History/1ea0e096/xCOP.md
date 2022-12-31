---
title: "c++中string转char时的传参问题"
date: 2022-02-17T00:56:27+08:00
draft: false
tags: ["cpp","leetcode"]
---
# string类型字符串转char型时候的函数传参问题
力扣1704题  
* 给你一个偶数长度的字符串 s 。将其拆分成长度相同的两半，前一半为 a ，后一半为 b 。

两个字符串 相似 的前提是它们都含有相同数目的元音（'a'，'e'，'i'，'o'，'u'，'A'，'E'，'I'，'O'，'U'）。注意，s 可能同时含有大写和小写字母。

如果 a 和 b 相似，返回 true ；否则，返回 false 。 *
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
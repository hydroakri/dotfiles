/*
 * @lc app=leetcode.cn id=791 lang=cpp
 *
 * [791] 自定义字符串排序
 *
 * https://leetcode.cn/problems/custom-sort-string/description/
 *
 * algorithms
 * Medium (70.19%)
 * Likes:    136
 * Dislikes: 0
 * Total Accepted:    22.5K
 * Total Submissions: 31K
 * Testcase Example:  '"cba"\n"abcd"'
 *
 * 给定两个字符串 order 和 s 。order 的所有单词都是 唯一 的，并且以前按照一些自定义的顺序排序。
 * 
 * 对 s 的字符进行置换，使其与排序的 order 相匹配。更具体地说，如果在 order 中的字符 x 出现字符 y 之前，那么在排列后的字符串中， x
 * 也应该出现在 y 之前。
 * 
 * 返回 满足这个性质的 s 的任意排列 。
 * 
 * 
 * 
 * 示例 1:
 * 
 * 
 * 输入: order = "cba", s = "abcd"
 * 输出: "cbad"
 * 解释: 
 * “a”、“b”、“c”是按顺序出现的，所以“a”、“b”、“c”的顺序应该是“c”、“b”、“a”。
 * 因为“d”不是按顺序出现的，所以它可以在返回的字符串中的任何位置。“dcba”、“cdba”、“cbda”也是有效的输出。
 * 
 * 示例 2:
 * 
 * 
 * 输入: order = "cbafg", s = "abcd"
 * 输出: "cbad"
 * 
 * 
 * 
 * 
 * 提示:
 * 
 * 
 * 1 <= order.length <= 26
 * 1 <= s.length <= 200
 * order 和 s 由小写英文字母组成
 * order 中的所有字符都 不同
 * 
 * 
 */

// @lc code=start
class Solution {
public:
    string customSortString(string order, string s) {
        
    }
};
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
// @lc code=end


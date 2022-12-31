/*
 * @lc app=leetcode.cn id=9 lang=cpp
 *
 * [9] 回文数
 */

// @lc code=start
class Solution {
public:
    bool isPalindrome(int x) {
    if (x<0)return false;
    int tmp=0,y=0;
    while (tmp!=0) {
        tmp=x%10;
        y=y*10+tmp;
    }
    }
};
// @lc code=end


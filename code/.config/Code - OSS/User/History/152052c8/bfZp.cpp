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
    long int tmp=0,y=0;
    long int xt=x;
    while (xt!=0) {
        tmp=xt%10;
        y=y*10+tmp;
        xt/=10;
    }
    return y==x;
    }
};
// @lc code=end


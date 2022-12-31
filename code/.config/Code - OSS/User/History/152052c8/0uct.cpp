/*
 * @lc app=leetcode.cn id=9 lang=cpp
 *
 * [9] 回文数
 */

// @lc code=start
class Solution {
public:
    bool isPalindrome(int x) {
    int length = 1;
    while (x /= 10)
    length++;
    bool sign=true;
    int j=length;
    for(int i=1;i<j/2;i++){
        if(x/10^(j-1)!=x%10) sign=false;
        --j;
        x/=10;
    }
    }
};
// @lc code=end


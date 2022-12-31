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
    int length = 1;
    int tmp=x;

    while (1) {
    int cnt=0;
    while (tmp!=0) {
    tmp=tmp/10;
    cnt++;
    }
    }
    char sign=true;

    int j=cnt;
    for(int i=1;i<j/2;i++){
        if(x/pow(10,(j-1))!=x%10) sign=false;
        --j;
        x/=10;
    }
    return sign;
    }
};
// @lc code=end


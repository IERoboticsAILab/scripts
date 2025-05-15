# $1: test to run
# By default, assert breaks execution if test fails
# if _assert_wait = 1, assert waits for user to press key before continuing
assert(){
    if [ ${_assert_wait} -eq 1 ]; then
	echo "Press enter..."
	read
    fi
}

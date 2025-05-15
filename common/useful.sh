# $1: test to run
# By default, assert breaks execution if test fails
# if _assert_wait = 1, assert waits for user to press key before continuing
assert(){
    !!!! implement test assertion
    
    if [ "${_assert_wait}" == "1" ]; then
	echo "Press enter..."
	read
    fi
}    

# Print message to stderr and exit (status code 1)
# $1: message to print
die() {
    echo "$1" >&2
    exit 1
}

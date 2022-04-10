function test() {
  TEST="1"
  export TEST_2="2"
  echo "rodou $TEST_3"
}

function exe() {
  TEST_3="3"
  test

  echo "$TEST-$TEST_2"
}

exe
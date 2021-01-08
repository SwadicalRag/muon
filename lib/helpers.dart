int roundToModulus(int n,int mod) {
  int rem = n % mod;
  n = n - rem;

  if(rem.abs() >= (mod ~/ 2).abs()) {
    n += rem * n.sign;
  }

  return n;
}

int floorToModulus(int n,int mod) {
  int rem = n % mod;
  n = n - rem;

  return n;
}

int ceilToModulus(int n,int mod) {
  int rem = n % mod;
  n = n - rem;

  return n + mod;
}

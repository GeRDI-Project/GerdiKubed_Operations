# Update Howto

0. Make sure no one calls the k8s apiserver (esp. the build server)
1. Add new machines (mstrs, lbs, nds)
2. Change all DNS-Records to new machines except external names of lb
3. Deploy cluster on new machines
4. Deploy gerdireleases
5. Test deployment
6. Change external names of lb
7. Shutdown of old machines after ~1 h

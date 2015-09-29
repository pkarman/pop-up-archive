(function () {

  /* Probably a better way to do this, but not that I could think of.
   * Chris Rhoden 2013 for PRX and Pop Up Archive.
   */

  var $realRootScope, actuallyIsLoading = 0, pretendLoading = 0, pageLoadings = 0;

  function loading (val) {
    if (val === true) {
      pretendLoading += 1;
    } else if (val === false) {
      pretendLoading -=1;
      if (pretendLoading < 0) pretendLoading = 0;
    } else {
      return (actuallyIsLoading || pretendLoading);
    }
  }

  function pageLoading (val) {
    if (val === true) {
      pageLoadings += 1;
    } else if (val === false) {
      pageLoadings -= 1;
      if (pageLoadings < 0) pageLoadings = 0;
    } else {
      return !!pageLoadings;
    }
  }

  angular.module('ngLoadingIndicators', [])
  .config(['$httpProvider', function ($httpProvider) {
    $httpProvider.responseInterceptors.push('myHttpInterceptor');
    function setIsLoading (data, headersGetter) {
      actuallyIsLoading += 1;
      return data;
    };
    $httpProvider.defaults.transformRequest.push(setIsLoading);
  }])
  .factory('myHttpInterceptor', ['$q', '$rootScope', '$location', function ($q, $rootScope, $location) {
    if (typeof $rootScope.setIsLoading === 'undefined') {
      $realRootScope = $rootScope;
      $rootScope.loading = loading;
      $rootScope.pageLoading = pageLoading;
    }

    return function (promise) {
      return promise.then(function success(response) {
        actuallyIsLoading -= 1;
        if (actuallyIsLoading < 0) actuallyIsLoading = 0;
        return response;
      }, function error(response) {
        var errCode = response.status.toString();
        // avoid recursion (error throwing error)
        // and only re-route if this was the main request (matches window.location) or 401, 403.
        // NOTE we silently skip 5xx and 404 responses because we do not want to alarm or mislead users
        // for ancillary objects that they are not requesting directly (as in search results, e.g.).
        //console.log("error " + errCode + " for path " + $location.path() + " for response", response);
        if (response && response.config) {
          var main_req = '/api' + $location.path();
          if (!$location.search().was && (response.config.url == main_req || !errCode.match(/^(404|5)/) ) ) {
            //console.log("redirect error " + errCode + " for response path " + response.config.url);
            $rootScope.errorLocation = response.config.url;
            $rootScope.prevLocation = $location.absUrl();
            $location.path('/error/' + errCode).search({was:$rootScope.prevLocation})
          }
        };
        actuallyIsLoading -= 1;
        if (actuallyIsLoading < 0) actuallyIsLoading = 0;
        return $q.reject(response);
      });
    };
  }])
  .factory('loading', function() {
    function maskedLoading (val) {
      return loading(val);
    }

    maskedLoading.page = function (val) {
      return pageLoading(val);
    }
    
    return maskedLoading;
  });
}());


angular.module('Directory.account.models', [])
.factory('Plan', ['Model', function (Model) {
  var Plan = new Model({url:'/api/plans', name: 'plan'});

  Plan.community = function () {
  	return this.get().then(function (plans) {
      var community;
      angular.forEach(plans, function (plan) {
        if (typeof community === 'undefined' && plan.id === "premium_community") {
          community = plan;
          community.is_community = true;
        }
      });
      return community;
  	});
  };

  return Plan;

}])

.factory('SampleAudio', ['Model', '$rootScope', 'Player', function (Model, $rootScope, Player) {
  $rootScope.exampleAudioFile = {
    url:  "https://s3.amazonaws.com/puatestfiles/newscast.mp3",
    duration: "00:00:35"
  };

  $rootScope.play = function (file) {
    Player.play(file);
    $rootScope.fileUrl = file;
    console.log('tried to play');
  };

  $rootScope.pause = function () {
    Player.pause();
  };

  $rootScope.rewind = function () {
    Player.rewind();
  };

  $rootScope.isLoaded = function () {
    return Player.nowPlayingUrl() === $rootScope.fileUrl;
  };

  $rootScope.isPlaying = function () {
    return $rootScope.isLoaded() && !Player.paused();
  };

}])


.factory('Subscribe', ['Model', '$rootScope', 'Plan', '$window', '$modal', '$location', function (Model, $rootScope, Plan, $window, $modal, $location) {
  $rootScope.interval = 'month';
  $rootScope.offer = $rootScope.offer || {};
  $rootScope.community = Plan.community();
  Plan.get().then(function(plans) {
    $rootScope.plans = [];
    plans.forEach(function(plan){
      switch(plan.id){
        case 'premium_community':
        case '25_small_business_mo':
        case '25_small_business_yr':
        case '20_small_business_mo':
        case '20_small_business_yr':
        case '10_small_business_mo':
        case '10_small_business_yr':
        case '5_small_business_mo':
        case '5_small_business_yr':
        case '1_small_business_mo':
        case '1_small_business_yr':
          $rootScope.plans.push(plan);
      }
    });
  });

  $rootScope.longInterval = false;
  $rootScope.planOffset = 3;
  $rootScope.togglePlans = function () {
    $rootScope.interval = ( $rootScope.interval == 'year' ? 'month' : 'year');
    $rootScope.longInterval = !$rootScope.longInterval;
    $rootScope.planOffset = ( $rootScope.planOffset == '2' ? '3' : '2');
  };

  $rootScope.hasFriendCoupon = function($location) {
    if (window.location['pathname'].includes('ui')) {
      var referrer_string = window.location.search.split('ui=')[1]
      var referrer_exists = referrer_string.match(/^[0-9]*$/g)
      if (referrer_exists != null)  {
        return true
      } else {
        return false
      }
    }  
  };

  $rootScope.isDisabled = function(plan) {
    if (plan.name == 'Community') {
      return true;
    } 
    else {
      return false;
    } 
  };

  $rootScope.getInterval = function() {
    return $rootScope.interval;
  };

  $rootScope.isPremiumPlan = function (plan) {
    if (plan.name === "Community"){
      return false;
    } else {
      return true;
    }
  };

  $rootScope.changePlan = function (plan) {
    switch(plan.id){
      case 'enterprise':
        $modal({template: '/assets/plans/form.html', persist: true, show: true, backdrop: 'static'});
        return;
      default: 
        subscribe(plan);
    }
  };
}]);

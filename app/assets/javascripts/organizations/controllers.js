angular.module('Directory.organizations.controllers', ['Directory.loader', 'Directory.user', 'Directory.organizations.models'])
.controller('OrganizationCtrl', ['$scope', '$route', 'Organization', 'Loader', 'Me', '$http', function OrganizationCtrl($scope, $route, Organization, Loader, Me, $http) {

  Me.authenticated(function (me) {
    Loader.page(Organization.get(me.organization.id), 'Organization', $scope).then(function (data) {
    });
  });

  $scope.sendOrgMemberInvite = function($event) {
    var org = $scope.organization;
    var btn = $($event.target);
    // make sure we actually have the button and not the icon
    var btnTag = btn.prop('tagName').toLowerCase();
    //console.log('btnTag:', btnTag);
    if (btnTag != 'button') {
      btn = btn.parent();
    }
    // the input field immediately precedes button
    var input = btn.prev();
    var email_addr = input.val();
    //console.log('org member: ', email_addr);
    
    // basic email validation
    if (!email_addr.match(/^.+\@.+\..+$/)) {
      //console.log('suspect email: ', email_addr);
      $scope.setMemberError('Invalid email address: ' + email_addr);
      return;
    }

    // post, reloading this page on success
    $http({
      data: { email: email_addr },
      url: '/api/organizations/'+org.id+'/member',
      method: 'POST'
    }).then(function(response) {
      $scope.addMessage({
        'type': 'success',
        'title': 'Invitation sent',
        'content': 'A invitation email has been sent to ' + email_addr
      });
      $route.reload();
    }, function(response) {
      // console.log(response);
      //var err = jQuery.parseJSON(jqXHR.responseText);
      //console.log(err);
      $scope.setMemberError('Something went wrong. Emails must correspond to users with existing Pop Up accounts.');
    });

  };

  $scope.setMemberError = function(msg) {
    //console.log("ERROR:", msg);
    $scope.addMessage({
      'type': 'warning',
      'title': 'Error',
      'content': msg
    });
  };

  $scope.deleteMember = function(user) {
    if (window.confirm("Are you sure you want to delete "+user.name+" from this organization?")) {
      var org = $scope.organization;
      $http({
        data: { user_id: user.id },
        url: '/api/organizations/'+org.id+'/member',
        method: 'PUT'
      }).then(function(data) {
        $scope.addMessage({
          'type': 'success',
          'title': 'User removed',
          'content': 'Successfully removed ' + user.name
        });
        $route.reload();
      }, function(response) {
        // console.log(response);
        $scope.setMemberError('Something went wrong. Please reload this page and try again.');
      });
    }
  };

}]);

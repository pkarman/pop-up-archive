angular.module('Directory.items.controllers', ['Directory.loader', 'Directory.user', 'Directory.items.models'])
.controller('ItemsCtrl', [ '$scope', 'Item', 'Loader', 'Me', function ItemsCtrl($scope, Item, Loader, Me) {
  Me.authenticated(function (data) {
    if ($scope.collectionId) {
      $scope.items = Loader.page(Item.query(), 'Items');
    }
  });
}])
.controller('ItemCtrl', ['$scope', 'Item', 'Loader', 'Me', '$routeParams', function ItemCtrl($scope, Item, Loader, Me, $routeParams) {

  if ($routeParams.id) {
    Loader.page(Item.get({collectionId:$routeParams.collectionId, id: $routeParams.id}), 'Item/'+$routeParams.id, $scope);
  }

  $scope.edit = function () {
    $scope.editItem = true;
  }

  $scope.close = function () {
    $scope.editItem = false;
  }

  $scope.$on("fileAdded", function (e, file) {
    $scope.item.addAudioFile(file).then(function(data) {
      $scope.item.audioFiles.push(data);
      $scope.addMessage({
        'type': 'success',
        'title': 'Congratulations!',
        'content': 'Your upload completed. <a data-dismiss="alert" href="' + $scope.item.link() + '">View and edit the item!</a>'
      });
    }, function(data){
      console.log('fileAdded: item: addAudioFile: reject', data, $scope.item);
    });
  });
}])
.controller('ItemFormCtrl', ['$scope', 'Schema', 'Item', function ($scope, Schema, Item) {

  $scope.item = {};
  $scope.$parent.$watch('item', function (is) {
    if (is && $scope.item != is) {
      angular.copy(is, $scope.item);
    }
  });

  $scope.fields = Schema.columns;
  // $scope.accessibleAttributes = Item.attrAccessible;

  $scope.submit = function () {
    if ($scope.item.id) {
      $scope.item.update().then(function (data) {
        angular.copy($scope.item, $scope.$parent.item);
        $scope.close();
      });
    } else {
      $scope.item.create().then(function (data) {
        if (angular.isFunction($scope.itemAdded)) {
          $scope.itemAdded($scope.item);
        }
        $scope.close();
      });
    }
  }
}]);

angular.module('Directory.users.models', ['RailsModel'])
.factory('CreditCard', ['Model', function (Model) {
  var CreditCard = Model({url:'/api/me/credit_card', name: 'credit_card'});
  return CreditCard;
}])
.factory('Subscription', ['Model', function (Model) {
  var Subscription = Model({url:'/api/me/subscription', name: 'subscription'});
  return Subscription;
}])
.factory('User', ['Model', 'CreditCard', 'Subscription', function (Model, CreditCard, Subscription) {
  var User = Model({url:'/api/users', name: 'user'});

  User.prototype.authenticated = function (callback, errback) {
    var self = this;
    if (self.id) {
      if (callback) {
        callback(self);
      }
      if (!self.usageSummaryByMonth) {
        self.usageSummaryByMonth = self.buildUsageSummary();
      }
      return true;
    }

    if (errback) {
      errback(self);
    }
    
    return false;
  };

  User.prototype.canEdit = function (obj) {
    if (this.authenticated() && obj && obj.collectionId) {
      return (this.collectionIds.indexOf(obj.collectionId) > -1);
    } else {
      return false;
    }
  };

  User.prototype.isAdmin = function () {
    if (this.authenticated()) {
      if (this.role == 'admin' || this.role == 'owner') {
        return true;
      }
      return false;
    } else {
      return false;
    }
  };

  User.prototype.updateCreditCard = function (stripeToken) {
    var cc = new CreditCard({token: stripeToken});
    return cc.update().then(function () {
      return User.get('me');
    });
  };

  User.prototype.hasCreditCard = function () {
    return !!this.creditCard;
  };

  User.prototype.isOrgMember = function() {
    return this.role == "member";
  };

  User.prototype.hasCommunityPlan = function () {
    return !!(!this.plan || !this.plan.id || this.plan.name.match(/Community/));
  };

  User.prototype.hasPremiumTranscripts = function() {
    return this.plan.isPremium;
  };

  User.prototype.defaultTranscriptType = function() {
    return this.hasPremiumTranscripts() ? "premium" : "basic";
  };

  User.prototype.buildUsageSummary = function() {
    var self = this;
    var groups = [];
    var curMonth = '';
    var group = [];
    // group by month, interleaving org with user if this user is in an Org
    var userInOrg = self.organization ? true : false;
    var mnthMap   = {};
    $.each(self.usage.summary.history, function(idx, msum) {
      if (self.plan.isPremium && msum.type.match(/basic/)) {
        return; // filter out some noise
      }
      if (msum.type.match(/usage only/)) {
        // clarify label
        msum.type = msum.type.replace(/usage only/, 'me');
      }
      else if (userInOrg) {
        return; // skip, use org version below
      }

      // initial cap
      msum.type = msum.type.charAt(0).toUpperCase() + msum.type.slice(1);

      if (msum.period != curMonth) {
        // new group
        if (group.length > 0) {
          groups.push({period: curMonth, rows: group});
          mnthMap[group[0].period] = groups.length - 1;
        }
        group = [msum];
        curMonth = msum.period;
      }
      else {
        group.push(msum);
      }
    });
    if (group.length > 0) {
      groups.push({period: curMonth, rows: group});
    }

    if (userInOrg) {
      // do the same with org usage, interleaving
      $.each(self.organization.usage.summary.history, function(idx, msum) {
        if (self.plan.isPremium && msum.type.match(/basic/)) {
          return; // filter out some noise
        }
        msum.type = msum.type.charAt(0).toUpperCase() + msum.type.slice(1);
        msum.type += ' ('+self.organization.name+')';
        // find the correct groups index to push to
        var gIdx = mnthMap[msum.period];
        // if could not match (not likely) then ... ??
        if (typeof gIdx == 'undefined') {
          console.log('no idx for ', msum, mnthMap);
          return;
        }
        groups[gIdx].rows.unshift(msum); // prepend
      });
    }
    return groups;
  };

  User.prototype.usageDetailsByMonth = function(ym) {
    if (this.organization) {
      return this.organization.usage.transcripts[ym];
    }
    else {
      return this.usage.transcripts[ym];
    } 
  };

  User.prototype.subscribe = function (planId, offerCode) {
    var sub = new Subscription({planId: planId});
    var self = this;
    if (typeof offerCode !== 'undefined') {
      sub.offer = offerCode;
    }
    return sub.update().then(function (plan) {
      return User.get('me');
    });
  };

  return User;
}])

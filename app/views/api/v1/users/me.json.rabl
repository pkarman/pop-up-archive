object false

if current_user
  cur_url = request.protocol + request.host
  if request.port != 80 and request.protocol == 'http://'
    cur_url += ':' + request.port.to_s
  end
  if request.port != 443 and request.protocol == 'https://'
    cur_url += ':' + request.port.to_s
  end
  node(:id) { current_user.id }
  node(:uri) { "#{cur_url}/api/users/#{current_user.id}" }
  node(:collection_ids) { current_user.collection_ids }
  node(:collections) { current_user.collections_title_id }
  node(:role) { current_user.role }

  node(:name) { current_user.name }
  node(:email) { current_user.email }

  node(:organization) {
    {
      id: current_user.organization.id,
      name: current_user.organization.name,
      amara_team: current_user.organization.amara_team,
      usage: { summary: current_user.organization.usage_summary, transcripts: current_user.organization.transcript_usage(DateTime.now) },
      owner_id: current_user.organization.owner_id,
    } if current_user.organization.present?
  }

  node(:used_metered_storage) { current_user.used_metered_storage_cache }
  node(:used_unmetered_storage) { current_user.used_unmetered_storage_cache }
  node(:total_metered_storage) { current_user.pop_up_hours * 3600 }
  node(:usage) { { summary: current_user.usage_summary, transcripts: current_user.transcript_usage } }
  node(:over_monthly_limit) { current_user.is_over_monthly_limit? }
  node(:plan) { current_user.plan_json }
  node(:credit_card) { current_user.active_credit_card_json } if current_user.active_credit_card.present?
  node(:has_card) { current_user.active_credit_card.present? }
end

# frozen_string_literal: true

class DirectoryItemsController < ApplicationController
  PAGE_SIZE = 50

  def index
    raise Discourse::InvalidAccess.new(:enable_user_directory) unless SiteSetting.enable_user_directory?

    period = params.require(:period)
    period_type = DirectoryItem.period_types[period.to_sym]
    raise Discourse::InvalidAccess.new(:period_type) unless period_type
    result = DirectoryItem.where(period_type: period_type).includes(:user)

    if params[:group]
      group = Group.find_by(name: params[:group])
      raise Discourse::InvalidParameters.new(:group) if group.blank?
      guardian.ensure_can_see!(group)
      guardian.ensure_can_see_group_members!(group)

      result = result.includes(user: :groups).where(users: { groups: { id: group.id } })
    else
      result = result.includes(user: :primary_group)
    end

    if params[:exclude_usernames]
      result = result.references(:user).where.not(users: { username: params[:exclude_usernames].split(",") })
    end

    order = params[:order] || DirectoryItem.headings.first
    dir = params[:asc] ? 'ASC' : 'DESC'
    if DirectoryItem.headings.include?(order.to_sym)
      result = result.order("directory_items.#{order} #{dir}")
    elsif params[:order] === 'username'
      result = result.order("users.#{order} #{dir}")
    end

    if period_type == DirectoryItem.period_types[:all]
      result = result.includes(:user_stat)
    end
    page = params[:page].to_i

    user_ids = nil
    if params[:name].present?
      user_ids = UserSearch.new(params[:name], include_staged_users: true).search.pluck(:id)
      if user_ids.present?
        # Add the current user if we have at least one other match
        if current_user && result.dup.where(user_id: user_ids).exists?
          user_ids << current_user.id
        end
        result = result.where(user_id: user_ids)
      else
        result = result.where('false')
      end
    end

    if params[:username]
      user_id = User.where(username_lower: params[:username].to_s.downcase).pluck_first(:id)
      if user_id
        result = result.where(user_id: user_id)
      else
        result = result.where('false')
      end
    end

    result_count = result.count
    result = result.limit(PAGE_SIZE).offset(PAGE_SIZE * page).to_a

    more_params = params.slice(:period, :order, :asc).permit!
    more_params[:page] = page + 1
    load_more_uri = URI.parse(directory_items_path(more_params))
    load_more_directory_items_json = "#{load_more_uri.path}.json?#{load_more_uri.query}"

    # Put yourself at the top of the first page
    if result.present? && current_user.present? && page == 0 && !params[:group].present?

      position = result.index { |r| r.user_id == current_user.id }

      # Don't show the record unless you're not in the top positions already
      if (position || 10) >= 10
        your_item = DirectoryItem.where(period_type: period_type, user_id: current_user.id).first
        result.insert(0, your_item) if your_item
      end

    end

    last_updated_at = DirectoryItem.last_updated_at(period_type)
    render_json_dump(directory_items: serialize_data(result, DirectoryItemSerializer),
                     meta: {
                        last_updated_at: last_updated_at,
                        total_rows_directory_items: result_count,
                        load_more_directory_items: load_more_directory_items_json
                      }
                    )
  end
end

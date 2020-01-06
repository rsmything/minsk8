import 'package:graphql_flutter/graphql_flutter.dart';

// TODO: заменить class Queries.getItems > namespace queries.getItems

class Queries {
  static final getItems = gql(r'''
    query getItems($next_created_at: timestamptz) {
      items(
        where: 
          {
            created_at: {_lte: $next_created_at}, 
            is_blocked: {_is_null: true}, 
            transferred_at: {_is_null: true}, 
            moderated_at: {_is_null: false}
          }, 
        order_by: {created_at: desc}
      ) {
        id
        created_at
        text
        member {
          id
          nickname
          banned_until
          last_activity_at
        }
        images
        expires_at
        price
        urgent
        location
        is_blocked
        win {
          created_at
        }
        wishes {
          created_at
        }
        is_promo
      }
    }
  ''');

  static final getItemsForInteresting = gql(r'''
    query getItemsForInteresting($next_created_at: timestamptz) {
      items(
        where: 
          {
            total_wishes: {_is_null: false},
            created_at: {_lte: $next_created_at}, 
            is_blocked: {_is_null: true}, 
            transferred_at: {_is_null: true}, 
            moderated_at: {_is_null: false}
          }, 
        order_by: {total_wishes: desc, created_at: desc}
      ) {
        id
        created_at
        text
        member {
          id
          nickname
          banned_until
          last_activity_at
        }
        images
        expires_at
        price
        urgent
        location
        is_blocked
        win {
          created_at
        }
        wishes {
          created_at
        }
        is_promo
      }
    }
  ''');

  static final getItemsForBest = gql(r'''
    query getItemsForBest($next_created_at: timestamptz) {
      items(
        where: 
          {
            price: {_is_null: false},
            created_at: {_lte: $next_created_at}, 
            is_blocked: {_is_null: true}, 
            transferred_at: {_is_null: true}, 
            moderated_at: {_is_null: false}
          }, 
        order_by: {price: desc, created_at: desc}
      ) {
        id
        created_at
        text
        member {
          id
          nickname
          banned_until
          last_activity_at
        }
        images
        expires_at
        price
        urgent
        location
        is_blocked
        win {
          created_at
        }
        wishes {
          created_at
        }
        is_promo
      }
    }
  ''');

  static final getItemsForPromo = gql(r'''
    query getItemsForPromo($next_created_at: timestamptz) {
      items(
        where: 
          {
            is_promo: {_is_null: false},
            created_at: {_lte: $next_created_at}, 
            is_blocked: {_is_null: true}, 
            transferred_at: {_is_null: true}, 
            moderated_at: {_is_null: false}
          }, 
        order_by: {created_at: desc}
      ) {
        id
        created_at
        text
        member {
          id
          nickname
          banned_until
          last_activity_at
        }
        images
        expires_at
        price
        urgent
        location
        is_blocked
        win {
          created_at
        }
        wishes {
          created_at
        }
        is_promo
      }
    }
  ''');

  static final getItemsForUrgent = gql(r'''
    query getItemsForUrgent($next_created_at: timestamptz) {
      items(
        where: 
          {
            urgent: {_eq: very_urgent},
            created_at: {_lte: $next_created_at}, 
            is_blocked: {_is_null: true}, 
            transferred_at: {_is_null: true}, 
            moderated_at: {_is_null: false}
          }, 
        order_by: {created_at: desc}
      ) {
        id
        created_at
        text
        member {
          id
          nickname
          banned_until
          last_activity_at
        }
        images
        expires_at
        price
        urgent
        location
        is_blocked
        win {
          created_at
        }
        wishes {
          created_at
        }
        is_promo
      }
    }
  ''');

  static final getItemsByKind = gql(r'''
    query getItemsByKind($next_created_at: timestamptz, $kind: kind_enum) {
      items(
        where: 
          {
            kind: {_eq: $kind},
            created_at: {_lte: $next_created_at} 
            is_blocked: {_is_null: true}, 
            transferred_at: {_is_null: true}, 
            moderated_at: {_is_null: false},
          }, 
        order_by: {created_at: desc}
      ) {
        id
        created_at
        text
        member {
          id
          nickname
          banned_until
          last_activity_at
        }
        images
        expires_at
        price
        urgent
        location
        is_blocked
        win {
          created_at
        }
        wishes {
          created_at
        }
        is_promo
      }
    }
  ''');

  static final getProfile = gql(r'''
    query getProfile($member_id: uuid!) {
      member_by_pk(id: $member_id) {
        nickname,
        id,
        my_items {
          images
        }
      }
    }
  ''');
}

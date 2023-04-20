import { PostScope } from '@/generated/types';
import { Choices } from '@/types/Choices';
import { IsExhaustive } from '../../utils/exhaustiveCheck';

export const postScopes = [
  { id: PostScope['PUBLIC'], name: '公開' },
  { id: PostScope['HOME'], name: 'ホーム' },
  { id: PostScope['FOLLOWERS_ONLY'], name: 'フォロワー限定' },
] satisfies Choices<PostScope>;

const _check: IsExhaustive<PostScope, typeof postScopes> = true;

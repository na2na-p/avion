import { Choices } from '@/types/Choices';
import { IsExhaustive } from '../../utils/exhaustiveCheck';
import { BaseRoleType } from '@/generated/types';

export const baseRoleTypes = [
  { id: BaseRoleType['ADMIN'], name: '管理者' },
  { id: BaseRoleType['MODERATOR'], name: 'モデレータ' },
  { id: BaseRoleType['USER'], name: 'ユーザ' },
  { id: BaseRoleType['BOT'], name: 'Bot' },
] satisfies Choices<BaseRoleType>;

const _check: IsExhaustive<BaseRoleType, typeof baseRoleTypes> = true;

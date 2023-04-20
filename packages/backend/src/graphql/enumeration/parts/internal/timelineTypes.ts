import { TimelineType } from '@/generated/types';
import { IsExhaustive } from '../../utils/exhaustiveCheck';

export const timelineTypes = [
  { id: TimelineType['GLOBAL_TIMELINE'], name: 'グローバルタイムライン' },
  { id: TimelineType['HOME_TIMELINE'], name: 'ホームタイムライン' },
  { id: TimelineType['LOCAL_TIMELINE'], name: 'ローカルタイムライン' },
  { id: TimelineType['ANTENNA_TIMELINE'], name: 'アンテナタイムライン' },
];

const _check: IsExhaustive<TimelineType, typeof timelineTypes> = true;

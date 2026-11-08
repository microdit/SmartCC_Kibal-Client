/** @format */

/**
 * clsx + tailwind-merge 스타일의 className 병합 유틸
 */
export function cn(...inputs: (string | undefined | null | false)[]) {
  return inputs.filter(Boolean).join(' ');
}

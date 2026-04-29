import { PageHeaderSkeleton, TableSkeleton } from "@/components/Skeleton";

export default function Loading() {
  return (
    <div className="space-y-6 p-6">
      <PageHeaderSkeleton />
      <TableSkeleton rows={6} cols={5} />
    </div>
  );
}

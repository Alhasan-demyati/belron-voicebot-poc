import { CardSkeleton, PageHeaderSkeleton } from "@/components/Skeleton";

export default function Loading() {
  return (
    <div className="space-y-6 p-6">
      <PageHeaderSkeleton />
      <CardSkeleton className="h-72" />
      <CardSkeleton className="h-80" />
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <CardSkeleton className="h-64" />
        <CardSkeleton className="h-64" />
        <CardSkeleton className="h-64" />
        <CardSkeleton className="h-64" />
      </div>
    </div>
  );
}
